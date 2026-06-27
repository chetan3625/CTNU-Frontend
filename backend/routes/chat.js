const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const { verifyToken } = require('../middleware/auth');
const User = require('../models/User');

// Get recent chats (users the current user has chatted with)
router.get('/recent', verifyToken, async (req, res) => {
  const userId = req.user.id;
  try {
    const messages = await Message.find({
      $or: [
        { from: userId },
        { to: userId }
      ]
    }).sort({ timestamp: -1 });

    const userIds = new Set();
    messages.forEach(msg => {
      userIds.add(msg.from.toString());
      userIds.add(msg.to.toString());
    });
    userIds.delete(userId); // remove current user

    const users = await User.find({ _id: { $in: Array.from(userIds) } })
      .select('_id username email isOnline lastSeen');

    const usersList = [];
    for (const u of users) {
      const unreadCount = await Message.countDocuments({
        from: u._id,
        to: userId,
        read: false
      });
      usersList.push({
        _id: u._id,
        username: u.username,
        email: u.email,
        unreadCount
      });
    }
    res.json(usersList);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get chat history between current user and another user
router.get('/history/:otherUserId', verifyToken, async (req, res) => {
  const userId = req.user.id;
  const otherUserId = req.params.otherUserId;
  try {
    // Mark incoming messages as read
    await Message.updateMany(
      { from: otherUserId, to: userId, read: false },
      { $set: { read: true } }
    );

    const messages = await Message.find({
      $or: [
        { from: userId, to: otherUserId },
        { from: otherUserId, to: userId }
      ]
    })
      .sort('timestamp')
      .select('_id from to content timestamp read');
    res.json(messages);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
