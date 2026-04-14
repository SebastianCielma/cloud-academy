const express = require('express');
const app = express();

app.get('/health', (req, res) => {
    res.status(200).json({ status: 'OK' });
});

app.get('/tasks', (req, res) => {
    res.status(200).json([{ id: 1, title: 'Learn Jenkins' }, { id: 2, title: 'Write tests' }]);
});

module.exports = app;

if (require.main === module) {
    const port = process.env.PORT || 3000;
    app.listen(port, () => console.log(`Server running on port ${port}`));
}