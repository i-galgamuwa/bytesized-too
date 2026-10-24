require('dotenv').config();
const express = require('express');
const path = require('path');
const session = require('express-session');
const helmet = require('helmet');
const morgan = require('morgan');

const pageRoutes = require('./routes/pages');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.set('trust proxy', 1);

// Security headers. CSP is left off because this starter loads Tailwind, Leaflet,
// Chart.js and Google Fonts from public CDNs — lock this down once those assets
// are self-hosted or bundled for production.
app.use(helmet({ contentSecurityPolicy: false }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

app.use(session({
  secret: process.env.SESSION_SECRET || 'change-this-secret-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    maxAge: 8 * 60 * 60 * 1000 // 8 hours
  }
}));

// Expose the logged-in admin to every view
app.use((req, res, next) => {
  res.locals.currentUser = req.session.user || null;
  next();
});

app.use('/', pageRoutes);
app.use('/api', apiRoutes);

app.use((req, res) => {
  res.status(404).send('Page not found');
});

// Centralized error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send('Something went wrong on the server.');
});

app.listen(PORT, () => {
  console.log(`GPS Sales Tracking Dashboard running at http://localhost:${PORT}`);
});
