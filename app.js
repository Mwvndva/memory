let memories = [
  {
    person: "Amara",
    initial: "A",
    time: "8 min ago",
    ageHours: 0.13,
    caption: "The ridiculous cake moment",
    avatar: "#FF6B57",
    background:
      "linear-gradient(135deg, #ff826e 0%, #ffc857 42%, #5ed6b3 100%)",
    message: "Send Amara a message",
  },
  {
    person: "Mum",
    initial: "M",
    time: "Yesterday",
    ageHours: 26,
    caption: "Found your old school song",
    avatar: "#5ED6B3",
    background:
      "linear-gradient(145deg, #5ed6b3 0%, #63b3ff 48%, #fff0b8 100%)",
    message: "Send Mum a message",
  },
  {
    person: "Leo",
    initial: "L",
    time: "Friday",
    ageHours: 72,
    caption: "Rainy walk after class",
    avatar: "#63B3FF",
    background:
      "linear-gradient(150deg, #63b3ff 0%, #bba7ff 45%, #ffb23e 100%)",
    message: "Send Leo a message",
  },
  {
    person: "Nia",
    initial: "N",
    time: "2 days ago",
    ageHours: 48,
    caption: "Sunset on the way home",
    avatar: "#BBA7FF",
    background:
      "linear-gradient(145deg, #bba7ff 0%, #ff6b57 45%, #ffc857 100%)",
    message: "Send Nia a message",
  },
];

const stage = document.querySelector("#memoryStage");
const mediaLayer = document.querySelector("#mediaLayer");
const avatar = document.querySelector("#avatar");
const personName = document.querySelector("#personName");
const memoryTime = document.querySelector("#memoryTime");
const caption = document.querySelector("#caption");
const dots = document.querySelector("#memoryDots");
const soundToggle = document.querySelector("#soundToggle");
const memoryGridButton = document.querySelector("#memoryGridButton");
const memoryGridCloseButton = document.querySelector("#memoryGridCloseButton");
const memoryGridPanel = document.querySelector("#memoryGridPanel");
const memoryGrid = document.querySelector("#memoryGrid");
const phone = document.querySelector(".phone");
const authScreens = Array.from(document.querySelectorAll("[data-auth-panel]"));
const loginButton = document.querySelector("#loginButton");
const loginIdentifierInput = document.querySelector("#loginIdentifierInput");
const loginPasswordInput = document.querySelector("#loginPasswordInput");
const showCreateAccountButton = document.querySelector("#showCreateAccountButton");
const backToLoginButton = document.querySelector("#backToLoginButton");
const createAccountForm = document.querySelector("#createAccountForm");
const firstNameInput = document.querySelector("#firstNameInput");
const lastNameInput = document.querySelector("#lastNameInput");
const usernameInput = document.querySelector("#usernameInput");
const signupEmailInput = document.querySelector("#signupEmailInput");
const countryCodeSelect = document.querySelector("#countryCodeSelect");
const usernameStatus = document.querySelector("#usernameStatus");
const passwordInput = document.querySelector("#passwordInput");
const confirmPasswordInput = document.querySelector("#confirmPasswordInput");
const passwordStatus = document.querySelector("#passwordStatus");
const avatarUploadInput = document.querySelector("#avatarUploadInput");
const avatarPreview = document.querySelector("#avatarPreview");
const finishAvatarButton = document.querySelector("#finishAvatarButton");
const skipAvatarButton = document.querySelector("#skipAvatarButton");
const finishContactsButton = document.querySelector("#finishContactsButton");
const contactRequestButtons = Array.from(document.querySelectorAll("[data-contact]"));
const tabs = Array.from(document.querySelectorAll(".tab"));
const views = Array.from(document.querySelectorAll("[data-view-panel]"));
const circleTab = document.querySelector('.tab[data-tab="circle"]');
const recordButton = document.querySelector("#recordButton");
const sendMemoryButton = document.querySelector("#sendMemoryButton");
const timerChip = document.querySelector("#timerChip");
const captureView = document.querySelector(".capture-view");
const draftCaption = document.querySelector("#draftCaption");
const cameraCard = document.querySelector("#cameraCard");
const addPersonButton = document.querySelector("#addPersonButton");
const chatButtons = Array.from(document.querySelectorAll("[data-chat]"));
const inboxPanel = document.querySelector("#inboxPanel");
const inboxBackButton = document.querySelector("#inboxBackButton");
const inboxAvatar = document.querySelector("#inboxAvatar");
const inboxName = document.querySelector("#inboxName");
const profileButton = document.querySelector("#profileButton");
const profilePanel = document.querySelector("#profilePanel");
const profileCloseButton = document.querySelector("#profileCloseButton");
const inboxMessages = document.querySelector(".messages");
const inboxRequestBanner = document.querySelector("#inboxRequestBanner");
const inboxRequestTitle = document.querySelector("#inboxRequestTitle");
const inboxRequestCopy = document.querySelector("#inboxRequestCopy");
const acceptRequestButton = document.querySelector("#acceptRequestButton");
const inboxCompose = document.querySelector(".inbox-compose");
const inboxComposeInput = inboxCompose.querySelector("input");
const themeButtons = Array.from(document.querySelectorAll("[data-theme]"));
const memoryPlusSheet = document.querySelector("#memoryPlusSheet");
const closeSheetButton = document.querySelector("#closeSheetButton");
const closeSheetBackdrop = document.querySelector("#closeSheetBackdrop");
const inviteSheet = document.querySelector("#inviteSheet");
const closeInviteButton = document.querySelector("#closeInviteButton");
const closeInviteBackdrop = document.querySelector("#closeInviteBackdrop");
const statShareSheet = document.querySelector("#statShareSheet");
const closeStatShareButton = document.querySelector("#closeStatShareButton");
const closeStatShareBackdrop = document.querySelector("#closeStatShareBackdrop");
const sendShareCardButton = document.querySelector("#sendShareCardButton");
const sharePreviewCard = document.querySelector("#sharePreviewCard");
const shareCardPlatform = document.querySelector("#shareCardPlatform");
const shareCardValue = document.querySelector("#shareCardValue");
const shareCardTitle = document.querySelector("#shareCardTitle");
const shareCardCopy = document.querySelector("#shareCardCopy");
const statShareButtons = Array.from(document.querySelectorAll("[data-share-stat]"));
const memoryComposer = document.querySelector("#memoryComposer");
const messageForm = document.querySelector("#messageForm");
const messageInput = document.querySelector("#messageInput");
const emojiButtons = Array.from(document.querySelectorAll(".emoji-rail button"));
const API_BASE = window.__MEMORY_API_BASE__ || "";

function apiPath(path) {
  return API_BASE ? `${API_BASE.replace(/\/$/, "")}${path}` : path;
}

const MEMORY_LIFETIME_HOURS = 24;

let activeIndex = 0;
let activeMemorySource = "feed";
let activeView = "memory";
let startY = 0;
let isDragging = false;
let wheelLock = false;
let soundOn = true;
let hasRecorded = false;
let movedDuringTouch = false;
let draftCaptionState = {
  left: 50,
  top: 62,
  size: 26,
};
const activeCaptionPointers = new Map();
let captionHoldTimer = null;
let captionDragActive = false;
let captionDragStart = null;
let captionPinchStart = null;
let memoryGridDrag = null;
let circleCount = 12;
const circleLimit = 30;
let activeSharePlatform = "";
let activeThreadName = "Amara";
const storageKey = "memory-prototype-state";
const unavailableUsernames = ["roy", "memory", "amara", "leo", "mum"];
let accountState = {
  email: "roy@memory.app",
  username: "roykeepsmemories",
  password: "Password1",
  firstName: "Roy",
  lastName: "Nthiga",
  avatarDataUrl: "",
};
const countries = [
  ["Kenya", "🇰🇪", "+254"],
  ["United States", "🇺🇸", "+1"],
  ["United Kingdom", "🇬🇧", "+44"],
  ["Canada", "🇨🇦", "+1"],
  ["Nigeria", "🇳🇬", "+234"],
  ["South Africa", "🇿🇦", "+27"],
  ["Ghana", "🇬🇭", "+233"],
  ["Uganda", "🇺🇬", "+256"],
  ["Tanzania", "🇹🇿", "+255"],
  ["Rwanda", "🇷🇼", "+250"],
  ["Ethiopia", "🇪🇹", "+251"],
  ["Egypt", "🇪🇬", "+20"],
  ["India", "🇮🇳", "+91"],
  ["Pakistan", "🇵🇰", "+92"],
  ["Bangladesh", "🇧🇩", "+880"],
  ["China", "🇨🇳", "+86"],
  ["Japan", "🇯🇵", "+81"],
  ["South Korea", "🇰🇷", "+82"],
  ["Australia", "🇦🇺", "+61"],
  ["New Zealand", "🇳🇿", "+64"],
  ["France", "🇫🇷", "+33"],
  ["Germany", "🇩🇪", "+49"],
  ["Italy", "🇮🇹", "+39"],
  ["Spain", "🇪🇸", "+34"],
  ["Netherlands", "🇳🇱", "+31"],
  ["Sweden", "🇸🇪", "+46"],
  ["Norway", "🇳🇴", "+47"],
  ["Brazil", "🇧🇷", "+55"],
  ["Mexico", "🇲🇽", "+52"],
  ["Argentina", "🇦🇷", "+54"],
  ["United Arab Emirates", "🇦🇪", "+971"],
  ["Saudi Arabia", "🇸🇦", "+966"],
  ["Turkey", "🇹🇷", "+90"],
  ["Israel", "🇮🇱", "+972"],
  ["Qatar", "🇶🇦", "+974"],
  ["Kuwait", "🇰🇼", "+965"],
  ["Bahrain", "🇧🇭", "+973"],
  ["Oman", "🇴🇲", "+968"],
  ["Jordan", "🇯🇴", "+962"],
  ["Lebanon", "🇱🇧", "+961"],
  ["Morocco", "🇲🇦", "+212"],
  ["Algeria", "🇩🇿", "+213"],
  ["Tunisia", "🇹🇳", "+216"],
  ["Senegal", "🇸🇳", "+221"],
  ["Cameroon", "🇨🇲", "+237"],
  ["Ivory Coast", "🇨🇮", "+225"],
  ["Zimbabwe", "🇿🇼", "+263"],
  ["Zambia", "🇿🇲", "+260"],
  ["Malawi", "🇲🇼", "+265"],
  ["Mozambique", "🇲🇿", "+258"],
  ["Botswana", "🇧🇼", "+267"],
  ["Namibia", "🇳🇦", "+264"],
  ["Angola", "🇦🇴", "+244"],
  ["Democratic Republic of the Congo", "🇨🇩", "+243"],
  ["Poland", "🇵🇱", "+48"],
  ["Portugal", "🇵🇹", "+351"],
  ["Belgium", "🇧🇪", "+32"],
  ["Switzerland", "🇨🇭", "+41"],
  ["Austria", "🇦🇹", "+43"],
  ["Ireland", "🇮🇪", "+353"],
  ["Denmark", "🇩🇰", "+45"],
  ["Finland", "🇫🇮", "+358"],
  ["Iceland", "🇮🇸", "+354"],
  ["Czech Republic", "🇨🇿", "+420"],
  ["Greece", "🇬🇷", "+30"],
  ["Romania", "🇷🇴", "+40"],
  ["Hungary", "🇭🇺", "+36"],
  ["Ukraine", "🇺🇦", "+380"],
  ["Philippines", "🇵🇭", "+63"],
  ["Indonesia", "🇮🇩", "+62"],
  ["Malaysia", "🇲🇾", "+60"],
  ["Singapore", "🇸🇬", "+65"],
  ["Thailand", "🇹🇭", "+66"],
  ["Vietnam", "🇻🇳", "+84"],
  ["Sri Lanka", "🇱🇰", "+94"],
  ["Nepal", "🇳🇵", "+977"],
  ["Chile", "🇨🇱", "+56"],
  ["Colombia", "🇨🇴", "+57"],
  ["Peru", "🇵🇪", "+51"],
  ["Ecuador", "🇪🇨", "+593"],
  ["Venezuela", "🇻🇪", "+58"],
  ["Uruguay", "🇺🇾", "+598"],
  ["Paraguay", "🇵🇾", "+595"],
  ["Bolivia", "🇧🇴", "+591"],
  ["Costa Rica", "🇨🇷", "+506"],
  ["Panama", "🇵🇦", "+507"],
  ["Jamaica", "🇯🇲", "+1"],
  ["Dominican Republic", "🇩🇴", "+1"],
];

const defaultThreadState = {
  Amara: {
    preview: "Voice reply: that cake was chaos",
    time: "8m",
    unread: 2,
    accepted: true,
    requestPending: false,
    memoryUnlocked: true,
    messages: [
      { mine: false, text: "I keep replaying that memory." },
      { mine: true, text: "Same. It made my whole day." },
      { mine: false, text: "Send another this weekend?" },
    ],
  },
  Mum: {
    preview: "Watched your weekend memory",
    time: "1h",
    unread: 0,
    accepted: true,
    requestPending: false,
    memoryUnlocked: true,
    messages: [
      { mine: false, text: "That old school song brought everything back." },
      { mine: true, text: "I knew you would remember it." },
    ],
  },
  Leo: {
    preview: "Sent a rainy walk memory",
    time: "Fri",
    unread: 1,
    accepted: true,
    requestPending: false,
    memoryUnlocked: true,
    messages: [
      { mine: false, text: "Your rainy walk memory was perfect." },
      { mine: true, text: "Thought you’d like that one." },
    ],
  },
  Nia: {
    preview: "Request pending",
    time: "Now",
    unread: 1,
    accepted: false,
    requestPending: true,
    memoryUnlocked: false,
    messages: [
      { mine: true, text: "I sent you a request to join my circle." },
    ],
  },
};

function cloneThreadState() {
  return JSON.parse(JSON.stringify(defaultThreadState));
}

function createDefaultAppState() {
  return {
    circleCount: 12,
    activeThreadName: "Amara",
    threads: cloneThreadState(),
  };
}

function loadAppState() {
  try {
    const stored = window.localStorage.getItem(storageKey);
    if (!stored) return createDefaultAppState();
    const parsed = JSON.parse(stored);
    if (parsed && parsed.memories) {
      memories = parsed.memories;
    }
    if (typeof parsed.circleCount === "number") {
      circleCount = parsed.circleCount;
    }
    if (parsed.activeThreadName) {
      activeThreadName = parsed.activeThreadName;
    }
    if (parsed.accountState) {
      accountState = {
        ...accountState,
        ...parsed.accountState,
      };
    }
    return {
      ...createDefaultAppState(),
      ...parsed,
      threads: {
        ...cloneThreadState(),
        ...(parsed.threads || {}),
      },
    };
  } catch {
    return createDefaultAppState();
  }
}

let appState = loadAppState();
circleCount = Number(appState.circleCount ?? circleCount);
appState.circleCount = circleCount;
activeThreadName = appState.activeThreadName || activeThreadName;

const shareStats = {
  memories: {
    title: "Memories",
    value: "14 days",
    copy: "I have kept my Memories alive for 14 days.",
    cardClass: "memories-share-card",
  },
  pulse: {
    title: "Circle Pulse",
    value: "8 days",
    copy: "My circle has kept the Pulse alive for 8 days.",
    cardClass: "pulse-share-card",
  },
};

function setAuthScreen(screenName) {
  phone.dataset.authScreen = screenName;
  authScreens.forEach((screen) => {
    screen.classList.toggle("active", screen.dataset.authPanel === screenName);
  });
}

function enterApp() {
  phone.dataset.authScreen = "app";
}

function populateCountries() {
  countryCodeSelect.innerHTML = countries
    .map(([name, flag, code]) => `<option value="${code}">${flag} ${name} ${code}</option>`)
    .join("");
}

async function loginWithCredentials() {
  const identifier = (loginIdentifierInput.value || accountState.email).trim();
  const password = loginPasswordInput.value || accountState.password;
  try {
    const response = await fetch(apiPath("/api/auth/login"), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        identifier,
        password,
      }),
    });
    if (!response.ok) return;
    const snapshot = await response.json();
    applyDatabaseSnapshot(snapshot);
    saveAppState();
    enterApp();
  } catch {
    const normalizedIdentifier = normalizeUsername(identifier);
    const matchesIdentifier = identifier.toLowerCase() === accountState.email || normalizedIdentifier === accountState.username;
    if (!matchesIdentifier || password !== accountState.password) return;
    enterApp();
  }
}

function normalizeUsername(value) {
  return value.trim().replace(/^@/, "").toLowerCase();
}

function checkUsernameAvailability() {
  const username = normalizeUsername(usernameInput.value);
  usernameStatus.classList.remove("available", "taken");

  if (username.length < 3) {
    usernameStatus.textContent = "Use at least 3 characters.";
    usernameStatus.classList.add("taken");
    return false;
  }

  if (username.length > 30) {
    usernameStatus.textContent = "Use 30 characters or fewer.";
    usernameStatus.classList.add("taken");
    return false;
  }

  if (!/^[a-z0-9._]+$/.test(username)) {
    usernameStatus.textContent = "Only letters, numbers, periods, and underscores.";
    usernameStatus.classList.add("taken");
    return false;
  }

  if (username.startsWith(".") || username.endsWith(".") || username.includes("..")) {
    usernameStatus.textContent = "Periods cannot start, end, or repeat.";
    usernameStatus.classList.add("taken");
    return false;
  }

  if (unavailableUsernames.includes(username)) {
    usernameStatus.textContent = `@${username} is taken.`;
    usernameStatus.classList.add("taken");
    return false;
  }

  usernameStatus.textContent = `@${username} is available.`;
  usernameStatus.classList.add("available");
  return true;
}

function validatePasswords() {
  passwordStatus.classList.remove("available", "taken");

  if (passwordInput.value.length < 8) {
    passwordStatus.textContent = "Use at least 8 characters.";
    passwordStatus.classList.add("taken");
    return false;
  }

  if (!/[a-z]/.test(passwordInput.value) || !/[A-Z]/.test(passwordInput.value)) {
    passwordStatus.textContent = "Use uppercase and lowercase letters.";
    passwordStatus.classList.add("taken");
    return false;
  }

  if (passwordInput.value !== confirmPasswordInput.value) {
    passwordStatus.textContent = "Passwords do not match.";
    passwordStatus.classList.add("taken");
    return false;
  }

  passwordStatus.textContent = "Passwords match.";
  passwordStatus.classList.add("available");
  return true;
}

function getFeedMemoryIndexes() {
  return memories
    .map((memory, index) => (memory.ageHours < MEMORY_LIFETIME_HOURS ? index : null))
    .filter((index) => index !== null);
}

function getArchivedMemoryIndexes() {
  return memories
    .map((memory, index) => (memory.ageHours >= MEMORY_LIFETIME_HOURS ? index : null))
    .filter((index) => index !== null);
}

function getGridMemoryIndexes() {
  const archivedMemoryIndexes = getArchivedMemoryIndexes();
  if (!archivedMemoryIndexes.length) return [];
  return Array.from({ length: 12 }, (_, index) => archivedMemoryIndexes[index % archivedMemoryIndexes.length]);
}

function buildDatabaseSnapshot() {
  appState.circleCount = circleCount;
  appState.activeThreadName = activeThreadName;
  appState.selectedTheme = phone.dataset.selectedTheme;
  const { password, ...safeAccountState } = accountState;
  return {
    memories,
    appState,
    circleCount,
    activeThreadName,
    accountState: safeAccountState,
    selectedTheme: phone.dataset.selectedTheme,
    profile: {
      firstName: accountState.firstName || "Roy",
      lastName: accountState.lastName || "Nthiga",
      email: accountState.email,
      phone: "+254 712 345 678",
      username: `@${accountState.username}`,
    },
  };
}

function applyDatabaseSnapshot(snapshot) {
  if (!snapshot || typeof snapshot !== "object") return;

  if (Array.isArray(snapshot.memories) && snapshot.memories.length) {
    memories = snapshot.memories;
  }

  if (snapshot.appState && typeof snapshot.appState === "object") {
    appState = {
      ...appState,
      ...snapshot.appState,
      threads: {
        ...(appState.threads || {}),
        ...(snapshot.appState.threads || {}),
      },
    };
  }

  if (typeof snapshot.circleCount === "number") {
    circleCount = snapshot.circleCount;
    appState.circleCount = circleCount;
  }

  if (snapshot.activeThreadName) {
    activeThreadName = snapshot.activeThreadName;
    appState.activeThreadName = activeThreadName;
  }

  if (snapshot.accountState && typeof snapshot.accountState === "object") {
    accountState = {
      ...accountState,
      ...snapshot.accountState,
    };
    if (snapshot.accountState.avatarDataUrl) {
      avatarPreview.style.backgroundImage = `url("${snapshot.accountState.avatarDataUrl}")`;
      avatarPreview.classList.add("has-image");
    }
  }

  if (snapshot.selectedTheme) {
    phone.dataset.selectedTheme = snapshot.selectedTheme;
    appState.selectedTheme = snapshot.selectedTheme;
    themeButtons.forEach((button) => {
      button.classList.toggle("active", button.dataset.theme === snapshot.selectedTheme);
    });
  }

  const profile = snapshot.profile || {};
  if (profile.firstName) accountState.firstName = profile.firstName;
  if (profile.lastName) accountState.lastName = profile.lastName;
  const profileAvatar = document.querySelector("#profileAvatar");
  const profileFullName = document.querySelector("#profileFullName");
  const profileHandle = document.querySelector("#profileHandle");
  const profileFirstName = document.querySelector("#profileFirstName");
  const profileLastName = document.querySelector("#profileLastName");
  const profileEmail = document.querySelector("#profileEmail");
  const profilePhone = document.querySelector("#profilePhone");
  const profileUsername = document.querySelector("#profileUsername");
  if (profileAvatar && profile.firstName) profileAvatar.textContent = profile.firstName.slice(0, 1).toUpperCase();
  if (profileFullName) profileFullName.textContent = `${profile.firstName || "Roy"} ${profile.lastName || "Nthiga"}`.trim();
  if (profileHandle) profileHandle.textContent = profile.username || `@${accountState.username}`;
  if (profileFirstName) profileFirstName.textContent = profile.firstName || "Roy";
  if (profileLastName) profileLastName.textContent = profile.lastName || "Nthiga";
  if (profileEmail) profileEmail.textContent = profile.email || accountState.email;
  if (profilePhone) profilePhone.textContent = profile.phone || "+254 712 345 678";
  if (profileUsername) profileUsername.textContent = profile.username || `@${accountState.username}`;
}

async function loadDatabaseSnapshot() {
  try {
    const response = await fetch(apiPath("/api/bootstrap"));
    if (!response.ok) return;
    const snapshot = await response.json();
    applyDatabaseSnapshot(snapshot);
  } catch {
    // Offline fallback keeps the prototype usable.
  }
}

function saveAppState() {
  const snapshot = buildDatabaseSnapshot();
  try {
    window.localStorage.setItem(storageKey, JSON.stringify(snapshot));
  } catch {
    // Local storage is optional in this prototype.
  }
  fetch(apiPath("/api/bootstrap"), {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(snapshot),
  }).catch(() => {});
}

function getThread(name) {
  if (!appState.threads[name]) {
    appState.threads[name] = {
      preview: "Request pending",
      time: "Now",
      unread: 1,
      accepted: false,
      requestPending: true,
      memoryUnlocked: false,
      messages: [{ mine: true, text: `I sent you a request to join my circle.` }],
    };
  }
  return appState.threads[name];
}

function updateProfileCircleCount() {
  circleCount = Math.min(circleLimit, appState.circleCount);
  const circleCountValue = document.querySelector("#circleCountValue");
  if (circleCountValue) {
    circleCountValue.textContent = `${circleCount} / ${circleLimit}`;
  }
}

function updateUnreadBadge() {
  const unreadTotal = Object.values(appState.threads).reduce(
    (total, thread) => total + (thread.unread || 0),
    0,
  );
  circleTab.dataset.count = unreadTotal > 0 ? String(unreadTotal) : "";
  circleTab.classList.toggle("has-badge", unreadTotal > 0);
}

function updateChatList() {
  chatButtons.forEach((button) => {
    const thread = getThread(button.dataset.chat);
    const copy = button.querySelector(".chat-copy small");
    const meta = button.querySelector(".chat-meta");
    button.classList.toggle("is-pending", !thread.accepted);
    if (copy) {
      copy.textContent = thread.preview;
    }
    if (meta) {
      meta.innerHTML = "";
      if (thread.unread > 0) {
        const unread = document.createElement("b");
        unread.textContent = String(thread.unread);
        meta.appendChild(unread);
      }
      const when = document.createElement("small");
      when.textContent = thread.time;
      meta.appendChild(when);
    }
  });
  updateUnreadBadge();
}

function createMessageBubble(message) {
  const bubble = document.createElement("p");
  bubble.className = `message ${message.mine ? "mine" : "theirs"}`;
  bubble.textContent = message.text;
  return bubble;
}

function renderInboxThread() {
  const thread = getThread(activeThreadName);
  const memory = memories.find((item) => item.person === activeThreadName) || memories[0];

  inboxAvatar.textContent = memory.initial;
  inboxAvatar.style.setProperty("--chat-color", memory.avatar);
  inboxName.textContent = activeThreadName;
  inboxRequestTitle.textContent = thread.accepted ? "Chat unlocked" : "Request pending";
  inboxRequestCopy.textContent = thread.accepted
    ? "You can now message each other."
    : "Accept to unlock the memory and message input.";
  inboxRequestBanner.hidden = thread.accepted;
  inboxCompose.classList.toggle("is-hidden", !thread.accepted);
  inboxMessages.innerHTML = "";

  if (!thread.memoryUnlocked) {
    const locked = document.createElement("div");
    locked.className = "memory-lock-card";
    const title = document.createElement("strong");
    title.textContent = "Memory hidden";
    const description = document.createElement("p");
    description.textContent = "You can only see this memory after the request is accepted.";
    locked.append(title, description);
    inboxMessages.appendChild(locked);
    if (!thread.accepted) {
      thread.messages.forEach((message) => inboxMessages.appendChild(createMessageBubble(message)));
    }
    return;
  }

  thread.messages.forEach((message) => inboxMessages.appendChild(createMessageBubble(message)));
}

function acceptActiveRequest() {
  const thread = getThread(activeThreadName);
  if (thread.accepted) return;
  thread.accepted = true;
  thread.requestPending = false;
  thread.memoryUnlocked = true;
  thread.preview = "Memory unlocked";
  thread.time = "Now";
  thread.unread = 0;
  appState.circleCount = Math.min(circleLimit, appState.circleCount + 1);
  thread.messages.push({ mine: false, text: "Request accepted. The chat is open now." });
  saveAppState();
  updateProfileCircleCount();
  updateChatList();
  renderInboxThread();
}

function sendContactRequest(name) {
  activeThreadName = name;
  appState.activeThreadName = name;
  const thread = getThread(name);
  thread.accepted = false;
  thread.requestPending = true;
  thread.memoryUnlocked = false;
  thread.preview = "Request sent";
  thread.time = "Now";
  thread.unread = Math.max(thread.unread || 0, 1);
  if (!thread.messages.length) {
    thread.messages = [{ mine: true, text: `I sent you a request to join my circle.` }];
  } else {
    thread.messages.push({ mine: true, text: `I sent you a request to join my circle.` });
  }
  saveAppState();
  updateProfileCircleCount();
  updateChatList();
  openInbox(name);
}

function currentMemoryIndexes() {
  return activeMemorySource === "grid" ? getGridMemoryIndexes() : getFeedMemoryIndexes();
}

function currentMemoryCount() {
  return currentMemoryIndexes().length;
}

function currentMemory() {
  return memories[currentMemoryIndexes()[activeIndex]];
}

function resetToCurrentMemory() {
  if (activeMemorySource === "feed" && activeIndex === 0) {
    updateMemoryGridButtonMode();
    return;
  }

  activeMemorySource = "feed";
  setMemory(0);
}

function updateMemoryGridButtonMode() {
  const isGridMemory = activeMemorySource === "grid" && !memoryGridPanel.classList.contains("open");
  memoryGridButton.classList.toggle("is-back", isGridMemory);
  memoryGridButton.setAttribute(
    "aria-label",
    isGridMemory ? "Back to all memories" : "Show memory grid",
  );
}

function renderDots() {
  dots.innerHTML = "";
  currentMemoryIndexes().forEach((_, index) => {
    const dot = document.createElement("button");
    dot.type = "button";
    dot.setAttribute("aria-label", `Show memory ${index + 1}`);
    dot.className = index === activeIndex ? "active" : "";
    dot.addEventListener("click", () => setMemory(index));
    dots.appendChild(dot);
  });
}

function renderMemoryGrid() {
  memoryGrid.innerHTML = "";
  getGridMemoryIndexes().forEach((memoryIndex, index) => {
    const memory = memories[memoryIndex];
    const item = document.createElement("button");
    item.type = "button";
    item.setAttribute("aria-label", `Open ${memory.person} memory`);
    item.style.setProperty("--memory-bg", memory.background);
    item.style.setProperty("--avatar-bg", memory.avatar);
    item.innerHTML = `<span>${memory.initial}</span>`;
    item.addEventListener("click", (event) => {
      event.stopPropagation();
      activeMemorySource = "grid";
      setMemory(index);
      closeMemoryGrid({ keepGridMemory: true });
    });
    memoryGrid.appendChild(item);
  });
}

function setMemory(index) {
  const memoryCount = currentMemoryCount();
  const next = (index + memoryCount) % memoryCount;
  activeIndex = next;
  const memory = currentMemory();
  const thread = getThread(memory.person);
  const isLocked = !thread.accepted && thread.requestPending;

  stage.classList.add("is-changing");
  stage.classList.toggle("is-locked", isLocked);
  mediaLayer.style.background = memory.background;
  avatar.textContent = memory.initial;
  avatar.style.background = memory.avatar;
  personName.textContent = memory.person;
  memoryTime.textContent = memory.time;
  caption.textContent = isLocked ? "Memory hidden until the request is accepted." : memory.caption;
  messageInput.placeholder = isLocked ? `Request ${memory.person} to unlock` : memory.message;
  hideComposer();
  renderDots();
  updateMemoryGridButtonMode();

  window.setTimeout(() => stage.classList.remove("is-changing"), 260);
}

function go(direction) {
  if (activeView !== "memory") return;
  setMemory(activeIndex + direction);
}

function openMemoryGrid() {
  hideComposer();
  memoryGridPanel.classList.add("open");
  memoryGridPanel.setAttribute("aria-hidden", "false");
  updateMemoryGridButtonMode();
}

function closeMemoryGrid(options = {}) {
  memoryGridPanel.classList.remove("open");
  memoryGridPanel.setAttribute("aria-hidden", "true");
  memoryGridPanel.style.transform = "";
  if (activeMemorySource === "grid" && !options.keepGridMemory) {
    resetToCurrentMemory();
    return;
  }
  updateMemoryGridButtonMode();
}

function setView(viewName) {
  activeView = viewName;
  phone.dataset.view = viewName;

  views.forEach((view) => {
    view.classList.toggle("active", view.dataset.viewPanel === viewName);
  });

  tabs.forEach((tab) => {
    const isActive = tab.dataset.tab === viewName;
    tab.classList.toggle("active", isActive);
    tab.setAttribute("aria-current", isActive ? "page" : "false");
  });

  if (viewName !== "circle") {
    closeInbox();
    closeProfile();
  }

  if (viewName !== "memory") {
    closeMemoryGrid();
    resetToCurrentMemory();
  }
}

function closeMemoryPlus() {
  memoryPlusSheet.classList.remove("open");
  memoryPlusSheet.setAttribute("aria-hidden", "true");
}

function openMemoryPlus() {
  memoryPlusSheet.classList.add("open");
  memoryPlusSheet.setAttribute("aria-hidden", "false");
}

function closeInviteSheet() {
  inviteSheet.classList.remove("open");
  inviteSheet.setAttribute("aria-hidden", "true");
}

function openInviteSheet() {
  inviteSheet.classList.add("open");
  inviteSheet.setAttribute("aria-hidden", "false");
}

function closeStatShareSheet() {
  statShareSheet.classList.remove("open");
  statShareSheet.setAttribute("aria-hidden", "true");
}

function openStatShareSheet(statKey, platform) {
  const stat = shareStats[statKey];
  if (!stat) return;

  activeSharePlatform = platform;
  sharePreviewCard.classList.remove("memories-share-card", "pulse-share-card");
  sharePreviewCard.classList.add(stat.cardClass);
  shareCardPlatform.textContent = platform;
  shareCardValue.textContent = stat.value;
  shareCardTitle.textContent = stat.title;
  shareCardCopy.textContent = stat.copy;
  sendShareCardButton.textContent = `Send to ${platform}`;
  statShareSheet.classList.add("open");
  statShareSheet.setAttribute("aria-hidden", "false");
}

function sendShareCard() {
  sendShareCardButton.textContent = `Sent to ${activeSharePlatform}`;
  window.setTimeout(closeStatShareSheet, 520);
}

function handleAddPerson() {
  if (circleCount < circleLimit) {
    openInviteSheet();
    return;
  }
  openMemoryPlus();
}

function closeInbox() {
  inboxPanel.classList.remove("open");
  inboxPanel.setAttribute("aria-hidden", "true");
}

function openInbox(name) {
  const memory = memories.find((item) => item.person === name) || memories[0];
  activeThreadName = name;
  appState.activeThreadName = name;
  inboxAvatar.textContent = memory.initial;
  inboxAvatar.style.setProperty("--chat-color", memory.avatar);
  inboxName.textContent = name;
  closeProfile();
  inboxPanel.classList.add("open");
  inboxPanel.setAttribute("aria-hidden", "false");
  renderInboxThread();
  saveAppState();
}

function closeProfile() {
  profilePanel.classList.remove("open");
  profilePanel.setAttribute("aria-hidden", "true");
}

function openProfile() {
  closeInbox();
  profilePanel.classList.add("open");
  profilePanel.setAttribute("aria-hidden", "false");
}

function showComposer() {
  if (activeView !== "memory") return;
  stage.classList.add("composer-open");
  document.querySelector(".memory-view").classList.add("composer-open");
  memoryComposer.classList.add("open");
  memoryComposer.setAttribute("aria-hidden", "false");
  messageInput.focus();
}

function hideComposer() {
  stage.classList.remove("composer-open");
  document.querySelector(".memory-view").classList.remove("composer-open");
  memoryComposer.classList.remove("open");
  memoryComposer.setAttribute("aria-hidden", "true");
  messageInput.value = "";
}

function toggleComposer() {
  if (memoryComposer.classList.contains("open")) {
    hideComposer();
  } else {
    showComposer();
  }
}

function renderDraftCaption() {
  draftCaption.style.left = `${draftCaptionState.left}%`;
  draftCaption.style.top = `${draftCaptionState.top}%`;
  draftCaption.style.fontSize = `${draftCaptionState.size}px`;
}

function setCaptionEditor(active) {
  captureView.classList.toggle("has-recording", active);
  draftCaption.setAttribute("contenteditable", active ? "true" : "false");
  renderDraftCaption();
}

stage.addEventListener("touchstart", (event) => {
  startY = event.touches[0].clientY;
  isDragging = true;
  movedDuringTouch = false;
});

stage.addEventListener("touchend", (event) => {
  if (!isDragging) return;
  const endY = event.changedTouches[0].clientY;
  const delta = endY - startY;
  if (Math.abs(delta) > 46) {
    movedDuringTouch = true;
    go(delta < 0 ? 1 : -1);
  } else if (!movedDuringTouch) {
    toggleComposer();
  }
  isDragging = false;
});

stage.addEventListener("click", (event) => {
  if (event.target.closest("button, input, form, .memory-composer, .memory-grid-panel")) return;
  toggleComposer();
});

stage.addEventListener("wheel", (event) => {
  if (wheelLock || Math.abs(event.deltaY) < 20) return;
  wheelLock = true;
  go(event.deltaY > 0 ? 1 : -1);
  window.setTimeout(() => {
    wheelLock = false;
  }, 520);
});

window.addEventListener("keydown", (event) => {
  if (event.key === "ArrowUp" || event.key === "ArrowRight") go(1);
  if (event.key === "ArrowDown" || event.key === "ArrowLeft") go(-1);
  if (event.key === "Escape") closeMemoryPlus();
});

soundToggle.addEventListener("click", () => {
  soundOn = !soundOn;
  soundToggle.classList.toggle("is-muted", !soundOn);
  soundToggle.setAttribute("aria-label", soundOn ? "Turn sound off" : "Turn sound on");
});

memoryGridButton.addEventListener("click", openMemoryGrid);
memoryGridCloseButton.addEventListener("click", (event) => {
  event.stopPropagation();
  closeMemoryGrid();
});

memoryGridPanel.addEventListener("pointerdown", (event) => {
  if (event.target.closest("button")) return;
  memoryGridPanel.setPointerCapture(event.pointerId);
  memoryGridDrag = { id: event.pointerId, startX: event.clientX };
});

memoryGridPanel.addEventListener("pointermove", (event) => {
  if (!memoryGridDrag || memoryGridDrag.id !== event.pointerId) return;
  const deltaX = Math.min(0, event.clientX - memoryGridDrag.startX);
  memoryGridPanel.style.transform = `translateX(${deltaX}px)`;
});

memoryGridPanel.addEventListener("pointerup", (event) => {
  if (!memoryGridDrag || memoryGridDrag.id !== event.pointerId) return;
  const deltaX = event.clientX - memoryGridDrag.startX;
  memoryGridDrag = null;
  if (deltaX < -70) {
    closeMemoryGrid();
    return;
  }
  memoryGridPanel.style.transform = "";
});

memoryGridPanel.addEventListener("pointercancel", () => {
  memoryGridDrag = null;
  memoryGridPanel.style.transform = "";
});

emojiButtons.forEach((button) => {
  button.addEventListener("click", () => {
    messageInput.value = `${messageInput.value}${button.textContent}`;
    messageInput.focus();
  });
});

messageForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const thread = getThread(activeThreadName);
  if (!thread.accepted) return;
  const value = messageInput.value.trim();
  if (!value) return;
  thread.messages.push({ mine: true, text: value });
  thread.preview = value;
  thread.time = "Now";
  thread.unread = 0;
  saveAppState();
  updateChatList();
  renderInboxThread();
  messageInput.value = "";
});

tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    hideComposer();
    if (tab.dataset.tab === "memory") {
      closeMemoryGrid();
      resetToCurrentMemory();
    }
    setView(tab.dataset.tab);
  });
});

recordButton.addEventListener("click", () => {
  hasRecorded = !hasRecorded;
  recordButton.classList.toggle("is-recording", hasRecorded);
  sendMemoryButton.disabled = !hasRecorded;
  timerChip.textContent = hasRecorded ? "0:12" : "0:30";
  sendMemoryButton.textContent = hasRecorded ? "Send to circle" : "Send to circle";
  setCaptionEditor(hasRecorded);
});

sendMemoryButton.addEventListener("click", () => {
  if (!hasRecorded) return;
  memories[0].caption = draftCaption.textContent.trim() || "A little weekend memory";
  hasRecorded = false;
  recordButton.classList.remove("is-recording");
  sendMemoryButton.disabled = true;
  timerChip.textContent = "0:30";
  setCaptionEditor(false);
  setMemory(0);
  setView("memory");
  saveAppState();
});

cameraCard.addEventListener("click", (event) => {
  if (!hasRecorded) return;
  if (event.target.closest("#draftCaption")) return;
  draftCaption.focus();
});

draftCaption.addEventListener("input", () => {
  if (!draftCaption.textContent.trim()) draftCaption.textContent = "";
});

function pointerDistance(points) {
  const [a, b] = points;
  return Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY);
}

draftCaption.addEventListener("pointerdown", (event) => {
  if (!hasRecorded) return;
  draftCaption.setPointerCapture(event.pointerId);
  activeCaptionPointers.set(event.pointerId, { clientX: event.clientX, clientY: event.clientY });

  if (activeCaptionPointers.size === 2) {
    window.clearTimeout(captionHoldTimer);
    captionDragActive = false;
    captionPinchStart = {
      distance: pointerDistance([...activeCaptionPointers.values()]),
      size: draftCaptionState.size,
    };
    return;
  }

  captionDragStart = {
    x: event.clientX,
    y: event.clientY,
    left: draftCaptionState.left,
    top: draftCaptionState.top,
  };
  captionHoldTimer = window.setTimeout(() => {
    captionDragActive = true;
    draftCaption.blur();
  }, 220);
});

draftCaption.addEventListener("pointermove", (event) => {
  if (!activeCaptionPointers.has(event.pointerId)) return;
  activeCaptionPointers.set(event.pointerId, { clientX: event.clientX, clientY: event.clientY });

  if (activeCaptionPointers.size === 2 && captionPinchStart) {
    const distance = pointerDistance([...activeCaptionPointers.values()]);
    const scale = distance / captionPinchStart.distance;
    draftCaptionState.size = Math.max(18, Math.min(40, Math.round(captionPinchStart.size * scale)));
    renderDraftCaption();
    return;
  }

  if (!captionDragActive || !captionDragStart) return;
  const rect = cameraCard.getBoundingClientRect();
  const deltaX = ((event.clientX - captionDragStart.x) / rect.width) * 100;
  const deltaY = ((event.clientY - captionDragStart.y) / rect.height) * 100;
  draftCaptionState.left = Math.max(20, Math.min(80, captionDragStart.left + deltaX));
  draftCaptionState.top = Math.max(22, Math.min(82, captionDragStart.top + deltaY));
  renderDraftCaption();
});

function endCaptionPointer(event) {
  window.clearTimeout(captionHoldTimer);
  activeCaptionPointers.delete(event.pointerId);
  if (activeCaptionPointers.size < 2) captionPinchStart = null;
  if (activeCaptionPointers.size === 0) {
    captionDragActive = false;
    captionDragStart = null;
  }
}

draftCaption.addEventListener("pointerup", endCaptionPointer);
draftCaption.addEventListener("pointercancel", endCaptionPointer);

addPersonButton.addEventListener("click", handleAddPerson);
closeSheetButton.addEventListener("click", closeMemoryPlus);
closeSheetBackdrop.addEventListener("click", closeMemoryPlus);
closeInviteButton.addEventListener("click", closeInviteSheet);
closeInviteBackdrop.addEventListener("click", closeInviteSheet);
closeStatShareButton.addEventListener("click", closeStatShareSheet);
closeStatShareBackdrop.addEventListener("click", closeStatShareSheet);
sendShareCardButton.addEventListener("click", sendShareCard);

statShareButtons.forEach((button) => {
  button.addEventListener("click", () => {
    openStatShareSheet(button.dataset.shareStat, button.dataset.sharePlatform);
  });
});

chatButtons.forEach((button) => {
  button.addEventListener("click", () => openInbox(button.dataset.chat));
});

inboxBackButton.addEventListener("click", closeInbox);
profileButton.addEventListener("click", openProfile);
profileCloseButton.addEventListener("click", closeProfile);

themeButtons.forEach((button) => {
  button.addEventListener("click", () => {
    themeButtons.forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    phone.dataset.selectedTheme = button.dataset.theme;
    appState.selectedTheme = button.dataset.theme;
    saveAppState();
  });
});

async function bootApp() {
  setMemory(0);
  phone.dataset.selectedTheme = appState.selectedTheme || "system";
  themeButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.theme === phone.dataset.selectedTheme);
  });
  populateCountries();
  renderMemoryGrid();
  updateProfileCircleCount();
  updateChatList();
  renderInboxThread();
  setView("memory");
  setCaptionEditor(false);
  await loadDatabaseSnapshot();
  renderMemoryGrid();
  updateProfileCircleCount();
  updateChatList();
  renderInboxThread();
  setMemory(0);
  setView("memory");
  setCaptionEditor(false);
  window.setTimeout(() => setAuthScreen("login"), 1200);
}

bootApp();

loginButton.addEventListener("click", loginWithCredentials);
showCreateAccountButton.addEventListener("click", () => setAuthScreen("create"));
backToLoginButton.addEventListener("click", () => setAuthScreen("login"));
usernameInput.addEventListener("input", checkUsernameAvailability);
passwordInput.addEventListener("input", validatePasswords);
confirmPasswordInput.addEventListener("input", validatePasswords);

avatarUploadInput.addEventListener("change", () => {
  const file = avatarUploadInput.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    const result = String(reader.result || "");
    avatarPreview.style.backgroundImage = `url("${result}")`;
    avatarPreview.classList.add("has-image");
    accountState.avatarDataUrl = result;
    saveAppState();
  };
  reader.readAsDataURL(file);
});

finishAvatarButton.addEventListener("click", () => setAuthScreen("contacts"));
skipAvatarButton.addEventListener("click", () => setAuthScreen("contacts"));
finishContactsButton.addEventListener("click", enterApp);

contactRequestButtons.forEach((button) => {
  button.addEventListener("click", () => sendContactRequest(button.dataset.contact));
});

acceptRequestButton.addEventListener("click", acceptActiveRequest);

createAccountForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!checkUsernameAvailability()) return;
  if (!validatePasswords()) return;
  accountState.email = signupEmailInput.value.trim().toLowerCase();
  accountState.username = normalizeUsername(usernameInput.value);
  accountState.password = passwordInput.value;
  accountState.firstName = firstNameInput.value.trim() || "Roy";
  accountState.lastName = lastNameInput.value.trim() || "Nthiga";
  try {
    const response = await fetch(apiPath("/api/auth/signup"), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: accountState.email,
        username: accountState.username,
        password: accountState.password,
        firstName: accountState.firstName,
        lastName: accountState.lastName,
        avatarDataUrl: accountState.avatarDataUrl,
      }),
    });
    if (response.ok) {
      const snapshot = await response.json();
      applyDatabaseSnapshot(snapshot);
      saveAppState();
    }
  } catch {
    saveAppState();
  }
  setAuthScreen("avatar");
});
