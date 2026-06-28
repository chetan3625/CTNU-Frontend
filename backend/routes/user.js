const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { isUserConnected } = require('../presence');

// Search users by username (partial match, case-insensitive)
router.get('/search', async (req, res) => {
  const { username } = req.query;
  if (!username) return res.status(400).json({ message: 'username query required' });
  try {
    const users = await User.find({
      username: { $regex: username, $options: 'i' },
      _id: { $ne: req.user.id }
    }).select('_id username email isOnline lastSeen');
    res.json(users.map((u) => ({
      _id: u._id,
      username: u.username,
      email: u.email,
      isOnline: isUserConnected(u._id.toString()),
      lastSeen: u.lastSeen,
    })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
