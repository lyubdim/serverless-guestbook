const FRONTEND_VERSION = "1.0.0";

const ui = {
  frontendVersion: document.getElementById("frontendVersion"),
  backendVersion: document.getElementById("backendVersion"),
  backendReplica: document.getElementById("backendReplica"),
  authorInput: document.getElementById("authorInput"),
  messageInput: document.getElementById("messageInput"),
  sendButton: document.getElementById("sendButton"),
  refreshButton: document.getElementById("refreshButton"),
  formStatus: document.getElementById("formStatus"),
  messagesList: document.getElementById("messagesList"),
  messageCount: document.getElementById("messageCount"),
};

ui.frontendVersion.textContent = `v${FRONTEND_VERSION}`;

function setStatus(text) {
  ui.formStatus.textContent = text;
}

function setBackendInfo(meta) {
  if (!meta) {
    return;
  }

  ui.backendVersion.textContent = `v${meta.backendVersion}`;
  ui.backendReplica.textContent = meta.backendReplica;
}

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("ru-RU", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function escapeText(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function renderMessages(messages) {
  ui.messageCount.textContent = messages.length;

  if (messages.length === 0) {
    ui.messagesList.innerHTML = '<div class="empty">Пока сообщений нет.</div>';
    return;
  }

  ui.messagesList.innerHTML = messages.map((item) => `
    <article class="message">
      <div class="message-header">
        <span class="message-author">${escapeText(item.author)}</span>
        <time datetime="${escapeText(item.createdAt)}">${escapeText(formatDate(item.createdAt))}</time>
      </div>
      <p class="message-text">${escapeText(item.message)}</p>
      <div class="message-meta">created by replica ${escapeText(item.backendReplica)}</div>
    </article>
  `).join("");
}

async function requestJson(path, options = {}) {
  const response = await fetch(path, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
    ...options,
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(payload.error || `HTTP ${response.status}`);
  }

  setBackendInfo(payload.meta);
  return payload;
}

async function loadHealth() {
  const payload = await requestJson("/api/health");
  setBackendInfo(payload);
}

async function loadMessages() {
  setStatus("Загружаю сообщения...");
  const payload = await requestJson("/api/messages");
  renderMessages(payload.messages || []);
  setStatus("Готово.");
}

async function submitMessage() {
  const author = ui.authorInput.value.trim() || "Аноним";
  const message = ui.messageInput.value.trim();

  if (!message) {
    setStatus("Напиши сообщение перед отправкой.");
    ui.messageInput.focus();
    return;
  }

  ui.sendButton.disabled = true;
  setStatus("Отправляю...");

  try {
    await requestJson("/api/messages", {
      method: "POST",
      body: JSON.stringify({ author, message }),
    });
    ui.messageInput.value = "";
    await loadMessages();
  } catch (error) {
    setStatus(`Ошибка: ${error.message}`);
  } finally {
    ui.sendButton.disabled = false;
  }
}

ui.sendButton.addEventListener("click", submitMessage);
ui.refreshButton.addEventListener("click", loadMessages);

loadHealth()
  .then(loadMessages)
  .catch((error) => {
    setStatus(`Не удалось подключиться к backend: ${error.message}`);
  });
