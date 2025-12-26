// Конфиг целей: веб (Vite/GitHub Pages) и Tauri build

// В режиме tauriBuild = true фронт ходит по прямому IP к бэкенду.
// В браузере (Vite dev server) должен быть false, чтобы работал proxy `/api` и не было CORS.
export const tauriBuild =
	typeof window !== 'undefined' && Boolean((window as any).__TAURI__)

export const tauriApiBase = 'http://127.0.0.1:8080'


export const webApiBase = ''

export const API_BASE = tauriBuild ? tauriApiBase : webApiBase
