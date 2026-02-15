# adshield-pro

## 코인 자동매매 앱에서 "테마 깨짐 + 로딩 미표시" 문제 트러블슈팅

서버 응답은 정상인데 UI에서 로딩이 안 보이고 테마가 뭉개지는 경우는 대부분 아래 4가지 축에서 발생합니다.

1. **로딩 상태(state)와 데이터 상태(state)가 분리되어 있지 않음**
2. **비동기 요청이 겹치면서 마지막 응답만 반영됨(경합)**
3. **초기 테마 적용이 늦어 FOUC(깜빡임/깨짐) 발생**
4. **CSS 우선순위/변수 누락으로 특정 컴포넌트만 기본 스타일로 렌더링됨**

---

## 1) 로딩 상태를 요청 단위로 명시하기

> "서버 통신은 되는데 로딩이 안 보인다"는 경우, `isLoading`이 전역 단일 boolean이라 다른 요청에서 덮어쓰는 경우가 많습니다.

### 권장 패턴
- 요청 키(`orders`, `positions`, `ticker`) 별 로딩 상태 관리
- `finally`에서 반드시 종료 처리
- 취소된 요청(`AbortController`)은 UI 실패로 간주하지 않기

```js
const loadingMap = {
  ticker: false,
  positions: false,
  orders: false,
};

async function fetchWithLoading(key, requestFn) {
  loadingMap[key] = true;
  render();

  try {
    const data = await requestFn();
    return data;
  } finally {
    loadingMap[key] = false;
    render();
  }
}
```

---

## 2) 오래 걸린 이전 응답이 최신 UI를 덮어쓰지 않게 하기

자동매매 대시보드는 주기 polling이 많아 race condition이 흔합니다.

### 권장 패턴
- 요청마다 증가하는 `requestId`를 두고, 최신 요청만 반영

```js
let latestTickerRequestId = 0;

async function loadTicker() {
  const requestId = ++latestTickerRequestId;
  setTickerLoading(true);

  try {
    const res = await fetch('/api/ticker');
    const data = await res.json();

    if (requestId !== latestTickerRequestId) return; // 오래된 응답 무시
    setTickerData(data);
  } finally {
    if (requestId === latestTickerRequestId) setTickerLoading(false);
  }
}
```

---

## 3) 테마 깨짐 방지: 앱 렌더 전에 테마 먼저 적용

테마가 뒤늦게 적용되면 컴포넌트가 기본 테마로 한번 렌더되며 "뭉개짐"처럼 보입니다.

### 권장 패턴
- 앱 마운트 전에 `data-theme` 또는 CSS 변수를 먼저 설정
- localStorage의 테마 값을 동기적으로 읽어 선적용

```html
<script>
  (function () {
    const saved = localStorage.getItem('theme') || 'dark';
    document.documentElement.setAttribute('data-theme', saved);
  })();
</script>
```

```css
:root[data-theme='dark'] {
  --bg: #0e1116;
  --text: #e8ecf2;
  --card: #171b22;
}

:root[data-theme='light'] {
  --bg: #ffffff;
  --text: #12151a;
  --card: #f4f6fa;
}

body {
  background: var(--bg);
  color: var(--text);
}
```

---

## 4) 로딩 표시가 실제로 보이도록 최소 조건 점검

- 로딩 컴포넌트가 `z-index` 뒤에 가려지지 않는지
- 부모가 `overflow: hidden`으로 스피너를 잘라내지 않는지
- 조건 렌더가 `data && <View/>` 같은 형태라 로딩 UI가 렌더 트리에서 제외되지 않는지
- 에러 상태와 로딩 상태가 동시에 true가 되지 않는지

권장 상태 모델:

```ts
status: 'idle' | 'loading' | 'success' | 'error'
```

boolean 2~3개 조합보다 단일 status enum이 화면 분기 실수를 줄여줍니다.

---

## 빠른 진단 체크리스트

- [ ] Network 탭에서 요청 성공(200) 확인
- [ ] 응답 직후 상태 업데이트 함수가 호출되는지 콘솔로 확인
- [ ] 상태 업데이트 후 렌더 함수/리액트 리렌더가 발생하는지 확인
- [ ] 동일 상태를 다른 effect가 다시 덮어쓰는지 확인
- [ ] 테마 관련 CSS 변수 누락(`var(--xxx)`) fallback 없는지 확인

---

## 다음 단계 제안

실제 코드(`로딩 상태 관리 파일`, `테마 초기화 코드`, `대시보드 렌더 컴포넌트`)를 공유하면,
- 정확히 어디서 상태가 덮이는지,
- 어떤 순서로 테마가 깨지는지,
- 최소 수정으로 안정화하는 패치
까지 바로 제안할 수 있습니다.
