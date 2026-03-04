import { Hono } from 'hono';
import type { HonoEnv } from '../env';

export const formRoutes = new Hono<HonoEnv>();

const HTML_CONTENT = `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>이슈 등록</title>
  <link rel="stylesheet" as="style" crossorigin href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v3.2.1/dist/web/static/pretendard.css" />
  <style>
    :root {
      --bg-color: #09090b;
      --card-bg: #18181b;
      --border-color: #27272a;
      --text-main: #fafafa;
      --text-muted: #a1a1aa;
      --primary: #ededed;
      --primary-hover: #ffffff;
      --primary-text: #09090b;
      --focus-ring: rgba(255, 255, 255, 0.15);
      --error-bg: rgba(239, 68, 68, 0.1);
      --error-border: #ef4444;
      --error-text: #fca5a5;
      --success-bg: rgba(34, 197, 94, 0.1);
      --success-border: #22c55e;
      --success-text: #86efac;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      background-color: var(--bg-color);
      color: var(--text-main);
      font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
      line-height: 1.6;
      display: flex;
      justify-content: center;
      padding: 2rem 1rem;
      min-height: 100vh;
    }

    .container {
      background-color: var(--card-bg);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 3rem 2.5rem;
      width: 100%;
      max-width: 600px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
    }

    header {
      margin-bottom: 2.5rem;
    }

    h1 {
      font-size: 1.875rem;
      font-weight: 700;
      letter-spacing: -0.025em;
      margin-bottom: 0.5rem;
    }

    header p {
      color: var(--text-muted);
      font-size: 1rem;
    }

    .form-group {
      margin-bottom: 1.5rem;
    }

    .row {
      display: flex;
      gap: 1rem;
      margin-bottom: 1.5rem;
    }

    .row .form-group {
      flex: 1;
      margin-bottom: 0;
    }

    label {
      display: block;
      font-size: 0.875rem;
      font-weight: 500;
      margin-bottom: 0.5rem;
      color: var(--text-main);
    }

    .required {
      color: var(--error-text);
      margin-left: 0.25rem;
    }

    input[type="text"],
    textarea,
    select {
      width: 100%;
      background-color: var(--bg-color);
      border: 1px solid var(--border-color);
      color: var(--text-main);
      border-radius: 8px;
      padding: 0.75rem 1rem;
      font-family: inherit;
      font-size: 0.9375rem;
      transition: all 0.2s ease;
      appearance: none;
    }

    textarea {
      resize: vertical;
      min-height: 120px;
    }

    input:focus,
    textarea:focus,
    select:focus {
      outline: none;
      border-color: var(--text-muted);
      box-shadow: 0 0 0 3px var(--focus-ring);
    }

    input::placeholder,
    textarea::placeholder {
      color: #52525b;
    }

    .select-wrapper {
      position: relative;
    }

    .select-wrapper::after {
      content: "▼";
      font-size: 0.7rem;
      color: var(--text-muted);
      position: absolute;
      right: 1rem;
      top: 50%;
      transform: translateY(-50%);
      pointer-events: none;
    }

    button {
      width: 100%;
      background-color: var(--primary);
      color: var(--primary-text);
      border: none;
      border-radius: 8px;
      padding: 1rem;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      transition: background-color 0.2s ease;
      display: flex;
      justify-content: center;
      align-items: center;
      margin-top: 1rem;
    }

    button:hover {
      background-color: var(--primary-hover);
    }

    button:disabled {
      opacity: 0.7;
      cursor: not-allowed;
    }

    .alert {
      padding: 1rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      font-size: 0.9375rem;
      display: none;
      border: 1px solid transparent;
    }

    .alert.error {
      display: block;
      background-color: var(--error-bg);
      border-color: var(--error-border);
      color: var(--error-text);
    }

    .alert.success {
      display: block;
      background-color: var(--success-bg);
      border-color: var(--success-border);
      color: var(--success-text);
    }

    .alert a {
      color: inherit;
      text-decoration: underline;
      font-weight: 600;
    }

    .spinner {
      border: 2px solid rgba(0,0,0,0.1);
      border-top: 2px solid var(--primary-text);
      border-radius: 50%;
      width: 1.25rem;
      height: 1.25rem;
      animation: spin 1s linear infinite;
      display: none;
    }

    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }

    @media (max-width: 640px) {
      .container {
        padding: 2rem 1.5rem;
        border-radius: 12px;
        border: none;
        box-shadow: none;
        background-color: transparent;
      }
      body {
        background-color: var(--card-bg);
        padding: 0;
      }
      .row {
        flex-direction: column;
        gap: 1.5rem;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>이슈 등록</h1>
      <p>새로운 버그나 기능 요청을 등록해주세요.</p>
    </header>

    <div id="alertBox" class="alert"></div>

    <form id="issueForm">
      <div class="form-group">
        <label for="title">제목 <span class="required">*</span></label>
        <input type="text" id="title" name="title" required placeholder="무엇을 도와드릴까요?">
      </div>

      <div class="row">
        <div class="form-group">
          <label for="type">유형</label>
          <div class="select-wrapper">
            <select id="type" name="type">
              <option value="🐛 버그">🐛 버그</option>
              <option value="✨ 기능 요청">✨ 기능 요청</option>
              <option value="🔧 유지보수">🔧 유지보수</option>
              <option value="📝 문서">📝 문서</option>
            </select>
          </div>
        </div>
        <div class="form-group">
          <label for="priority">우선순위</label>
          <div class="select-wrapper">
            <select id="priority" name="priority">
              <option value="🟢 낮음">🟢 낮음</option>
              <option value="🟡 보통" selected>🟡 보통</option>
              <option value="🟠 높음">🟠 높음</option>
              <option value="🔴 긴급">🔴 긴급</option>
            </select>
          </div>
        </div>
      </div>

      <div class="form-group">
        <label for="description">설명 <span class="required">*</span></label>
        <textarea id="description" name="description" required placeholder="상세한 내용을 입력해주세요..."></textarea>
      </div>

      <div class="form-group">
        <label for="labels">추가 라벨</label>
        <input type="text" id="labels" name="labels" placeholder="예: frontend, urgent (쉼표로 구분)">
      </div>

      <button type="submit" id="submitBtn">
        <span class="btn-text">등록하기</span>
        <span class="spinner" id="spinner"></span>
      </button>
    </form>
  </div>

  <script>
    const form = document.getElementById('issueForm');
    const submitBtn = document.getElementById('submitBtn');
    const btnText = document.querySelector('.btn-text');
    const spinner = document.getElementById('spinner');
    const alertBox = document.getElementById('alertBox');

    function showAlert(message, isError = true) {
      alertBox.className = 'alert ' + (isError ? 'error' : 'success');
      alertBox.innerHTML = message;
    }

    function setLoading(isLoading) {
      submitBtn.disabled = isLoading;
      if (isLoading) {
        btnText.style.display = 'none';
        spinner.style.display = 'block';
      } else {
        btnText.style.display = 'block';
        spinner.style.display = 'none';
      }
    }

    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      alertBox.className = 'alert';

      const formData = new FormData(form);
      const payload = {
        title: formData.get('title'),
        type: formData.get('type'),
        priority: formData.get('priority'),
        description: formData.get('description'),
        labels: formData.get('labels')
      };

      setLoading(true);

      try {
        const res = await fetch('/api/issues', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(payload)
        });

        const data = await res.json();

        if (!res.ok) {
          throw new Error(data.error?.message || '알 수 없는 오류가 발생했습니다.');
        }

        showAlert(\`✅ 성공적으로 등록되었습니다! <a href="\${data.issue.html_url}" target="_blank">이슈 #\${data.issue.number} 보기</a>\`, false);
        form.reset();
      } catch (err) {
        showAlert('❌ ' + err.message, true);
      } finally {
        setLoading(false);
      }
    });
  </script>
</body>
</html>`;

formRoutes.get('/', (c) => {
  return c.html(HTML_CONTENT);
});
