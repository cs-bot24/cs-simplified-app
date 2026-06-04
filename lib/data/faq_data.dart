import '../models/faq_model.dart';

/// Static FAQ data for v1.
/// Future migration path: replace this list with an API call that returns
/// the same FaqCategory/FaqItem structure — the UI layer needs zero changes.
const List<FaqCategory> faqData = [

  // ── General ─────────────────────────────────────────────────────────────────
  FaqCategory(category: 'General', items: [
    FaqItem(
      id: 1,
      category: 'General',
      question: 'What is CS Simplified?',
      answer:
          'CS Simplified is a learning platform created to help Computer '
          'Science students access study materials, exam preparation resources, '
          'and academic support in one place.',
      tags: ['about', 'platform', 'intro'],
    ),
    FaqItem(
      id: 2,
      category: 'General',
      question: 'Who created CS Simplified?',
      answer:
          'CS Simplified was created by Khalid Anas to make learning easier, '
          'more organized, and more accessible for Computer Science students.',
      tags: ['creator', 'developer', 'khalid'],
    ),
  ]),

  // ── Materials ────────────────────────────────────────────────────────────────
  FaqCategory(category: 'Materials', items: [
    FaqItem(
      id: 3,
      category: 'Materials',
      question: 'How do I download study materials?',
      answer:
          'Open a course, select a material, and tap Download. Downloaded '
          'materials may be available offline depending on your device '
          'settings and app version.',
      tags: ['download', 'offline', 'pdf', 'materials'],
    ),
    FaqItem(
      id: 4,
      category: 'Materials',
      question: 'How do I request a material?',
      answer:
          'Go to Support Center → Request a Material. Submit your request '
          'with the material title and any relevant details. The admin will '
          'review it and reply.',
      tags: ['request', 'material', 'past questions', 'notes'],
    ),
    FaqItem(
      id: 5,
      category: 'Materials',
      question: 'Why can\'t I find a particular material?',
      answer:
          'Possible reasons:\n'
          '• The material has not yet been uploaded.\n'
          '• The material belongs to another level or semester.\n'
          '• The material is currently under review.\n\n'
          'You may use Search or submit a Material Request.',
      tags: ['missing', 'not found', 'material', 'search'],
    ),
  ]),

  // ── Streak & Leaderboard ─────────────────────────────────────────────────────
  FaqCategory(category: 'Streak & Leaderboard', items: [
    FaqItem(
      id: 6,
      category: 'Streak & Leaderboard',
      question: 'How does the Study Streak work?',
      answer:
          'Study streaks are earned through meaningful study activity. '
          'Simply opening the app does not increase a streak — the system '
          'tracks genuine learning engagement.',
      tags: ['streak', 'study', 'daily', 'fire'],
    ),
    FaqItem(
      id: 7,
      category: 'Streak & Leaderboard',
      question: 'How does the Leaderboard work?',
      answer:
          'Leaderboard rankings are based on learning consistency and '
          'engagement. Factors may include your current Study Streak, '
          'total Study Days, and overall Learning Activity. '
          'The goal is to reward genuine study habits.',
      tags: ['leaderboard', 'ranking', 'points', 'score'],
    ),
    FaqItem(
      id: 8,
      category: 'Streak & Leaderboard',
      question: 'Why did my streak not increase today?',
      answer:
          'A streak only increases when the minimum study activity '
          'requirement has been met. Opening the app briefly does not '
          'count as studying.',
      tags: ['streak', 'not increasing', 'reset', 'study'],
    ),
  ]),

  // ── Notifications ────────────────────────────────────────────────────────────
  FaqCategory(category: 'Notifications', items: [
    FaqItem(
      id: 9,
      category: 'Notifications',
      question: 'Why am I not receiving notifications?',
      answer:
          'Check the following:\n'
          '• Notification permission is enabled in your device settings.\n'
          '• Your internet connection is active.\n'
          '• You have the latest version of the app installed.\n\n'
          'If the issue persists, contact support.',
      tags: ['notifications', 'not receiving', 'permission', 'alerts'],
    ),
    FaqItem(
      id: 10,
      category: 'Notifications',
      question: 'Who can see my material requests and support tickets?',
      answer:
          'Only you and authorized administrators can see your private '
          'requests and messages. Other users cannot access your requests, '
          'replies, or communications.',
      tags: ['privacy', 'private', 'notifications', 'requests'],
    ),
  ]),

  // ── Support ──────────────────────────────────────────────────────────────────
  FaqCategory(category: 'Support', items: [
    FaqItem(
      id: 11,
      category: 'Support',
      question: 'How do I contact the admin?',
      answer:
          'Open the Support Center from the Profile screen or the main menu. '
          'Available options include:\n'
          '• Support Ticket\n'
          '• Material Request\n'
          '• WhatsApp\n'
          '• Telegram\n'
          '• Email',
      tags: ['contact', 'admin', 'support', 'help', 'whatsapp', 'email'],
    ),
    FaqItem(
      id: 12,
      category: 'Support',
      question: 'How do I track my request?',
      answer:
          'Open the Support Center, then tap:\n'
          '• My Material Requests — to track material requests.\n'
          '• My Support Requests — to track support tickets.\n\n'
          'You can view the current status, admin replies, and any updates.',
      tags: ['track', 'request', 'status', 'reply', 'support'],
    ),
  ]),

  // ── Account & Privacy ────────────────────────────────────────────────────────
  FaqCategory(category: 'Account & Privacy', items: [
    FaqItem(
      id: 13,
      category: 'Account & Privacy',
      question: 'How do I delete my account?',
      answer:
          'Go to Profile → Settings → Delete Account.\n\n'
          'Warning: Deleting your account permanently removes your profile '
          'and all associated data. You may register again later using '
          'the same email address.',
      tags: ['delete', 'account', 'remove', 'data'],
    ),
    FaqItem(
      id: 14,
      category: 'Account & Privacy',
      question: 'Is my information private?',
      answer:
          'Yes. Your requests, tickets, and communications with the admin '
          'are private and only visible to you and authorized administrators. '
          'No other user can see your data.',
      tags: ['privacy', 'private', 'data', 'secure', 'information'],
    ),
  ]),
];
