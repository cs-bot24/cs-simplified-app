import '../models/faq_model.dart';

/// Static FAQ data.
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
          'AI-powered tutoring, and academic support in one place.',
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

  // ── AI Tutor ─────────────────────────────────────────────────────────────────
  FaqCategory(category: 'AI Tutor', items: [
    FaqItem(
      id: 15,
      category: 'AI Tutor',
      question: 'What is the AI Tutor?',
      answer:
          'The AI Tutor is a built-in academic assistant powered by Google '
          'Gemini. It can answer course questions, explain concepts, help '
          'with exam preparation, and generate practice questions and study '
          'notes — available 24/7 from the home screen.',
      tags: ['ai', 'tutor', 'gemini', 'assistant', 'chat'],
    ),
    FaqItem(
      id: 16,
      category: 'AI Tutor',
      question: 'How do I use the AI Tutor?',
      answer:
          'Tap the AI Tutor card on the home screen. Type your question and '
          'tap Send. You can also upload an image of a question — the AI will '
          'read and answer it directly.\n\n'
          'You can switch between Normal Mode and Exam Prep Mode, and choose '
          'your explanation level: Beginner, Intermediate, or Advanced.',
      tags: ['ai', 'how to', 'question', 'image', 'exam prep'],
    ),
    FaqItem(
      id: 17,
      category: 'AI Tutor',
      question: 'Can I send a photo of a question to the AI?',
      answer:
          'Yes. Tap the image icon in the AI Tutor chat, take a photo or '
          'choose one from your gallery, and send it. The AI will analyse '
          'the image and answer the question even if you do not type anything.',
      tags: ['image', 'photo', 'camera', 'ai', 'question'],
    ),
    FaqItem(
      id: 18,
      category: 'AI Tutor',
      question: 'What is Exam Prep Mode?',
      answer:
          'Exam Prep Mode adjusts the AI\'s responses to be more focused '
          'and exam-oriented. The AI will:\n'
          '• Keep answers concise and structured.\n'
          '• Highlight what examiners typically look for.\n'
          '• Point out common student mistakes.\n'
          '• Include a "Likely exam angle" tip where relevant.\n\n'
          'Toggle it on using the switch at the top of the AI Tutor screen.',
      tags: ['exam prep', 'mode', 'ai', 'study'],
    ),
    FaqItem(
      id: 19,
      category: 'AI Tutor',
      question: 'How do I use AI inside the PDF viewer?',
      answer:
          'While reading any material, you will see a floating AI button '
          'on the screen. Tap it to open the AI Tutor without leaving the PDF '
          '— your reading position is preserved.\n\n'
          'You can also tap the Study Tools bar at the bottom of the PDF:\n'
          '• Explain — AI summarises the material and highlights key concepts.\n'
          '• Notes — AI generates structured study notes with exam tips.\n'
          '• Quiz Me — AI generates practice questions from the material.\n\n'
          'The AI automatically knows which course material you are reading '
          'so all responses are course-relevant.',
      tags: ['pdf', 'ai', 'reader', 'explain', 'notes', 'quiz'],
    ),
    FaqItem(
      id: 20,
      category: 'AI Tutor',
      question: 'Can the AI generate practice questions?',
      answer:
          'Yes. In the AI Tutor chat, tap the Practice Questions button to '
          'generate exam-style questions on any topic. Inside the PDF viewer, '
          'tap Quiz Me to generate questions based on the current material.',
      tags: ['practice', 'questions', 'quiz', 'ai', 'exam'],
    ),
    FaqItem(
      id: 21,
      category: 'AI Tutor',
      question: 'Can the AI generate study notes?',
      answer:
          'Yes. In the AI Tutor chat, tap the Study Notes button. Inside '
          'the PDF viewer, tap Notes in the Study Tools bar. The AI will '
          'create structured notes including Key Concepts, Definitions, '
          'Important Points, and Exam Tips.',
      tags: ['notes', 'study', 'ai', 'generate', 'revision'],
    ),
    FaqItem(
      id: 22,
      category: 'AI Tutor',
      question: 'Why did the AI not analyse my image?',
      answer:
          'Image analysis requires the Gemini AI service to be available. '
          'If Gemini is temporarily unavailable, you will see a message '
          'asking you to type your question instead. This is a temporary '
          'situation — try again in a few minutes or type out your question.',
      tags: ['image', 'ai', 'error', 'not working', 'gemini'],
    ),
  ]),

  // ── Study Planner ─────────────────────────────────────────────────────────────
  FaqCategory(category: 'Study Planner', items: [
    FaqItem(
      id: 23,
      category: 'Study Planner',
      question: 'What is the Study Planner?',
      answer:
          'The Study Planner is an AI-powered scheduling tool. You tell it '
          'your course, goal, deadline, and how many hours you can study '
          'per day — the AI builds a complete week-by-week study schedule '
          'broken into daily sessions automatically.',
      tags: ['study planner', 'schedule', 'ai', 'plan'],
    ),
    FaqItem(
      id: 24,
      category: 'Study Planner',
      question: 'How do I create a study plan?',
      answer:
          'Tap the Planner tab at the bottom of the screen, or tap the '
          'Study Planner card on the home screen. Tap New Plan, fill in:\n'
          '• Course code and name\n'
          '• Your goal (e.g. Pass MTH104 with a B)\n'
          '• Start and end dates\n'
          '• Study hours available per day\n\n'
          'Tap Generate Plan with AI — the AI creates your full schedule '
          'in seconds.',
      tags: ['create', 'plan', 'study planner', 'how to'],
    ),
    FaqItem(
      id: 25,
      category: 'Study Planner',
      question: 'How do I mark a study session as complete?',
      answer:
          'Open the Today tab in the Study Planner — it shows all sessions '
          'scheduled for today. Tap the Done button next to a session when '
          'you finish it. Your plan progress updates instantly.',
      tags: ['complete', 'session', 'done', 'study planner', 'progress'],
    ),
    FaqItem(
      id: 26,
      category: 'Study Planner',
      question: 'How is my study plan progress calculated?',
      answer:
          'Progress is calculated as the percentage of sessions you have '
          'completed out of the total sessions in the plan. When you reach '
          '100%, the plan is automatically marked as Completed.',
      tags: ['progress', 'percentage', 'complete', 'study planner'],
    ),
    FaqItem(
      id: 27,
      category: 'Study Planner',
      question: 'Can I have multiple study plans at once?',
      answer:
          'Yes. You can create a separate study plan for each course. All '
          'active plans appear in the My Plans tab. The Today tab collects '
          'sessions from all your active plans into one daily view.',
      tags: ['multiple', 'plans', 'courses', 'study planner'],
    ),
    FaqItem(
      id: 28,
      category: 'Study Planner',
      question: 'Can I delete a study plan?',
      answer:
          'Yes. On the My Plans tab, tap the three-dot menu on any plan '
          'and select Delete. This removes the plan and all its sessions '
          'permanently.',
      tags: ['delete', 'remove', 'plan', 'study planner'],
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
          'If the issue persists, try logging out and back in, then contact support.',
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
