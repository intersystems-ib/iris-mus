import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import es from "./locales/es.json";
import en from "./locales/en.json";

const STORAGE_KEY = "iris-mus-language";

const storedLanguage = window.localStorage.getItem(STORAGE_KEY);
const initialLanguage =
  storedLanguage === "en" || storedLanguage === "es"
    ? storedLanguage
    : undefined;

void i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      es: { translation: es },
      en: { translation: en },
    },

    ...(initialLanguage ? { lng: initialLanguage } : {}),

    fallbackLng: "es",
    supportedLngs: ["es", "en"],
    nonExplicitSupportedLngs: true,

    interpolation: {
      escapeValue: false,
    },

    detection: {
      order: ["localStorage", "navigator"],
      caches: ["localStorage"],
      lookupLocalStorage: STORAGE_KEY,
    },

    react: {
      bindI18n: "languageChanged loaded",
      bindI18nStore: "added removed",
      useSuspense: false,
    },

    returnNull: false,
  });

i18n.on("languageChanged", (language) => {
  document.documentElement.lang = language.startsWith("en") ? "en" : "es";
});

export default i18n;
