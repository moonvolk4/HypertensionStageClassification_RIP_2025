self.addEventListener('install', (event) => {
  // Аккуратно: можно добавить предзагрузку статики, пока оставляем минимальный вариант
  console.log('Service worker installed');
});

self.addEventListener('activate', (event) => {
  console.log('Service worker activated');
});

self.addEventListener('fetch', (event) => {
  // Базовое требование методички: перехватываем запросы
  // Здесь можно реализовать кэширование, пока только логируем
  // console.log('Fetch:', event.request.url);
});
