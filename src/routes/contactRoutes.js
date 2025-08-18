import express from 'express';
import { body } from 'express-validator';
import { sendContactMessage } from '../controllers/contactController.js';

const router = express.Router();

const validateContact = [
  body('name').trim().notEmpty().withMessage('Name is required'),
  body('email').isEmail().withMessage('Valid email is required'),
  body('phone').optional().isMobilePhone().withMessage('Valid phone required'),
  body('subject').trim().notEmpty().withMessage('Subject is required'),
  body('message').trim().notEmpty().withMessage('Message is required'),
];

router.post('/', validateContact, sendContactMessage);

export default router;
