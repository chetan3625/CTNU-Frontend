require('dotenv').config();
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

io.on('connection', (socket) => {
  console.log(`User connected: ${socket.user.id}`);
  socket.on('private_message', async ({ to, content }) => {
    const Message = require('./models/Message');
    const message = await Message.create({ from: socket.user.id, to, content, timestamp: new Date() });
    // emit to recipient if online
    for (let [id, s] of io.sockets.sockets) {
      if (s.user && s.user.id === to) {
        s.emit('private_message', message);
        break;
      }
    }
    // also emit back to sender for UI update
    socket.emit('private_message', message);
  });
});

const PORT = process.env.PORT || 5000;
const DB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/chetanu';

mongoose.connect(DB_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => {
    console.log('MongoDB connected');
    server.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
  })
  .catch(err => console.error('MongoDB connection error:', err));
