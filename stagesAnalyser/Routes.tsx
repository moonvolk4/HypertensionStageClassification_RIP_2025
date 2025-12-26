export const ROUTES = {
  HOME: "/",
  ALBUMS: "/stages",
  LOGIN: "/login",
  REGISTER: "/register",
  RECORDS: "/records",
  PROFILE: "/profile",
  VACANCYAPPLICATION: "/vacancy_application",
}
export type RouteKeyType = keyof typeof ROUTES;
export const ROUTE_LABELS: {[key in RouteKeyType]: string} = {
  HOME: "Главная",
  ALBUMS: "Стадии",
  LOGIN: "Авторизация",
  REGISTER: "Регистрация",
  RECORDS: "Мои заявки",
  PROFILE: "Личный кабинет",
  VACANCYAPPLICATION: "Заявка",
};