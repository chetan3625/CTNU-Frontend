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
  }
});

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
  const userId = socket.user.id;
  console.log(`User connected: ${userId}`);
  
  // Join a room unique to this user ID
  socket.join(userId);

  // Set user as online
  try {
    const User = require('./models/User');
    await User.findByIdAndUpdate(userId, { isOnline: true });
    socket.broadcast.emit('user_status', { userId, isOnline: true });

    // Send the list of other currently online users to the newly connected user
    const onlineUsers = await User.find({ isOnline: true }).select('_id');
    for (const onlineUser of onlineUsers) {
      const onlineUserIdStr = onlineUser._id.toString();
      if (onlineUserIdStr !== userId) {
        socket.emit('user_status', { userId: onlineUserIdStr, isOnline: true });
      }
    }
  } catch (err) {
    console.error('Error updating user online status:', err);
  }

  socket.on('private_message', async ({ to, content }) => {
    try {
      const Message = require('./models/Message');
      const message = await Message.create({ 
        from: userId, 
        to, 
        content, 
        timestamp: new Date() 
      });
      
      // Emit to recipient's room
      io.to(to).emit('private_message', message);
      
      // Emit back to all of sender's sockets/sessions
      io.to(userId).emit('private_message', message);
    } catch (err) {
      console.error('Error handling private message:', err);
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  socket.on('typing', ({ to, isTyping }) => {
    io.to(to).emit('typing', { from: userId, isTyping });
  });

  socket.on('get_user_status', async ({ userId: targetUserId }) => {
    try {
      const User = require('./models/User');
      const targetUser = await User.findById(targetUserId).select('isOnline lastSeen');
      if (targetUser) {
        socket.emit('user_status', { 
          userId: targetUserId, 
          isOnline: targetUser.isOnline ?? false, 
          lastSeen: targetUser.lastSeen 
        });
      }
    } catch (err) {
      console.error('Error getting user status:', err);
    }
  });

  socket.on('mark_as_read', async ({ messageId, from }) => {
    try {
      const Message = require('./models/Message');
      await Message.updateOne({ _id: messageId }, { $set: { read: true } });
    } catch (err) {
      console.error('Error marking message as read:', err);
    }
  });

  socket.on('disconnect', async () => {
    console.log(`User disconnected: ${userId}`);
    try {
      const User = require('./models/User');
      const now = new Date();
      await User.findByIdAndUpdate(userId, { isOnline: false, lastSeen: now });
      socket.broadcast.emit('user_status', { userId, isOnline: false, lastSeen: now });
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
