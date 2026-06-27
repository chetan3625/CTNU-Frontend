const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const { verifyToken } = require('../middleware/auth');

// Get chat history between current user and another user
router.get('/history/:otherUserId', verifyToken, async (req, res) => {
  const userId = req.user.id;
  const otherUserId = req.params.otherUserId;
  try {
    const messages = await Message.find({
      $or: [
        { from: userId, to: otherUserId },
        { from: otherUserId, to: userId }
      ]
    })
      .sort('timestamp')
      .select('_id from to content timestamp');
    res.json(messages);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
