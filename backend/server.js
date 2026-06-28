const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '.env') });

const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/user');
const chatRoutes = require('./routes/chat');
const { verifyToken } = require('./middleware/auth');

const app = express();
app.use(cors());
app.use(express.json());
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});
app.use('/api/auth', authRoutes);
app.use('/api/users', verifyToken, userRoutes);
app.use('/api/chats', verifyToken, chatRoutes);

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  },
  pingInterval: 10000,
  pingTimeout: 5000,
  transports: ['websocket', 'polling'],
});

// Track active socket connections per user (supports app + background handoff)
const userConnections = new Map();

function serializeMessage(doc) {
  return {
    _id: doc._id.toString(),
    from: doc.from.toString(),
    to: doc.to.toString(),
    content: doc.content,
    timestamp: doc.timestamp instanceof Date
      ? doc.timestamp.toISOString()
      : new Date(doc.timestamp).toISOString(),
    read: doc.read ?? false,
    clientTempId: doc.clientTempId ?? null,
  };
}

function serializeUserStatus(userId, isOnline, lastSeen) {
  return {
    userId: userId.toString(),
    isOnline,
    lastSeen: lastSeen ? new Date(lastSeen).toISOString() : null,
  };
}

async function setUserOnline(userId) {
  const User = require('./models/User');
  await User.findByIdAndUpdate(userId, { isOnline: true });
  io.emit('user_status', serializeUserStatus(userId, true, null));
}

async function setUserOffline(userId) {
  const User = require('./models/User');
  const now = new Date();
  await User.findByIdAndUpdate(userId, { isOnline: false, lastSeen: now });
  io.emit('user_status', serializeUserStatus(userId, false, now));
}

function addUserConnection(userId, socketId) {
  if (!userConnections.has(userId)) {
    userConnections.set(userId, new Set());
  }
  const connections = userConnections.get(userId);
  const wasOffline = connections.size === 0;
  connections.add(socketId);
  return wasOffline;
}

function removeUserConnection(userId, socketId) {
  const connections = userConnections.get(userId);
  if (!connections) return true;
  connections.delete(socketId);
  if (connections.size === 0) {
    userConnections.delete(userId);
    return true;
  }
  return false;
}

io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) return next(new Error('Authentication error'));
  try {
    const payload = await verifyToken(token);
    socket.user = payload;
    next();
  } catch (e) {
    next(new Error('Authentication error'));
  }
});

io.on('connection', async (socket) => {
  const userId = socket.user.id.toString();
  console.log(`User connected: ${userId} (${socket.id})`);

  socket.join(userId);

  try {
    const wasOffline = addUserConnection(userId, socket.id);
    if (wasOffline) {
      await setUserOnline(userId);
    }

    const User = require('./models/User');
    const onlineUsers = await User.find({ isOnline: true }).select('_id lastSeen');
    for (const onlineUser of onlineUsers) {
      const onlineUserIdStr = onlineUser._id.toString();
      if (onlineUserIdStr !== userId) {
        socket.emit(
          'user_status',
          serializeUserStatus(onlineUserIdStr, true, onlineUser.lastSeen)
        );
      }
    }
  } catch (err) {
    console.error('Error updating user online status:', err);
  }

  socket.on('private_message', async ({ to, content, clientTempId }) => {
    if (!to || !content?.trim()) {
      socket.emit('error', { message: 'Invalid message payload' });
      return;
    }

    try {
      const Message = require('./models/Message');
      const message = await Message.create({
        from: userId,
        to: to.toString(),
        content: content.trim(),
        timestamp: new Date(),
      });

      const payload = serializeMessage(message);
      if (clientTempId) {
        payload.clientTempId = clientTempId;
      }

      io.to(to.toString()).emit('private_message', payload);
      io.to(userId).emit('private_message', payload);
    } catch (err) {
      console.error('Error handling private message:', err);
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  socket.on('typing', ({ to, isTyping }) => {
    if (!to) return;
    io.to(to.toString()).emit('typing', { from: userId, isTyping: !!isTyping });
  });

  socket.on('get_user_status', async ({ userId: targetUserId }) => {
    if (!targetUserId) return;
    try {
      const User = require('./models/User');
      const targetUser = await User.findById(targetUserId).select('isOnline lastSeen');
      if (targetUser) {
        socket.emit(
          'user_status',
          serializeUserStatus(
            targetUserId,
            targetUser.isOnline ?? false,
            targetUser.lastSeen
          )
        );
      }
    } catch (err) {
      console.error('Error getting user status:', err);
    }
  });

  socket.on('mark_as_read', async ({ messageId }) => {
    if (!messageId) return;
    try {
      const Message = require('./models/Message');
      await Message.updateOne({ _id: messageId }, { $set: { read: true } });
    } catch (err) {
      console.error('Error marking message as read:', err);
    }
  });

  socket.on('mark_chat_read', async ({ otherUserId }) => {
    if (!otherUserId) return;
    try {
      const Message = require('./models/Message');
      await Message.updateMany(
        { from: otherUserId, to: userId, read: false },
        { $set: { read: true } }
      );
    } catch (err) {
      console.error('Error marking chat as read:', err);
    }
  });

  socket.on('disconnect', async () => {
    console.log(`User disconnected: ${userId} (${socket.id})`);
    try {
      const isFullyOffline = removeUserConnection(userId, socket.id);
      if (isFullyOffline) {
        await setUserOffline(userId);
      }
    } catch (err) {
      console.error('Error updating user offline status:', err);
    }
  });
});

const PORT = process.env.PORT || 5000;
const DB_URI = process.env.MONGODB_URI?.trim();

const startServer = () => {
  server.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
};

if (!DB_URI) {
  console.warn('MongoDB URI is not set. Starting server without database connection. Set MONGODB_URI to enable DB-backed features.');
  startServer();
} else {
  mongoose.connect(DB_URI, { useNewUrlParser: true, useUnifiedTopology: true })
    .then(() => {
      console.log('MongoDB connected');
      startServer();
    })
    .catch(err => {
      console.error('MongoDB connection error:', err.message);
      console.warn('Starting server without database connection. Set MONGODB_URI to a real MongoDB URI to enable DB-backed features.');
      startServer();
    });
}
