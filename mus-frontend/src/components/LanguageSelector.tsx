import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";

const STORAGE_KEY = "iris-mus-language";

export function LanguageSelector() {
  const { t, i18n } = useTranslation();
  const [language, setLanguage] = useState(
    i18n.resolvedLanguage?.startsWith("en") ? "en" : "es"
  );

  useEffect(() => {
    const handleLanguageChanged = (nextLanguage: string) => {
      setLanguage(nextLanguage.startsWith("en") ? "en" : "es");
    };

    i18n.on("languageChanged", handleLanguageChanged);

    return () => {
      i18n.off("languageChanged", handleLanguageChanged);
    };
  }, [i18n]);

  async function handleLanguageChange(nextLanguage: string) {
    const normalizedLanguage = nextLanguage === "en" ? "en" : "es";

    window.localStorage.setItem(STORAGE_KEY, normalizedLanguage);

    await i18n.changeLanguage(normalizedLanguage);

    document.documentElement.lang = normalizedLanguage;

    /*
      La aplicación contiene algunos helpers que usan i18n.t() fuera de
      componentes React. La recarga garantiza que todo se reconstruya con
      el nuevo idioma y evita textos residuales del idioma anterior.
    */
    window.location.reload();
  }

  return (
    <label className="language-selector">
      <span>{t("common.language")}</span>
      <select
        value={language}
        onChange={(event) => {
          void handleLanguageChange(event.target.value);
        }}
        aria-label={t("common.language")}
      >
        <option value="es">{t("languages.es")}</option>
        <option value="en">{t("languages.en")}</option>
      </select>
    </label>
  );
}
