export enum Locale {
    ENGLISH = "en",
    GERMAN = "de",
    JAPANESE = "ja",
}

type Translation = Readonly<Record<Locale, string>>;

export const FooterTranslation = {
    rights : {
        en: "All rights reserved",
        de: "Alle Rechte vorbehalten",
        ja: "TODO"
    },

    legal_notice : {
        en: "Legal Notice",
        de: "Impressum",
        ja: "TODO"
    },

    ai_policy : {
        en: "This page contains no AI-generated content",
        de: "Diese Seite enthält keine KI-erstellte Inhalte",
        ja: "TODO"
    }
} satisfies Record<string, Translation>;

export const LanguageChooserTranslation = {
    label : {
        en: "English",
        de: "Deutsch",
        ja: "日本語"
    },

    title : {
        en: "Switch to english",
        de: "Zu Deutsch wechseln",
        ja: "TODO"
    }
} satisfies Record<string, Translation>;

export const HeaderBarTranslation = {
    title : {
        ["home"]: {
            en: "Home",
            de: "Startseite",
            ja: "TODO",
        },

        ["about"]: {
            en: "About",
            de: "Über Uns",
            ja: "TODO"
        },

        ["faq"]: {
            en: "Frequently asked questions",
            de: "Häufig gestellte fragen",
            ja: "TODO"
        },

        ["contact"]: {
            en: "Contact",
            de: "Kontakt",
            ja: "TODO"
        },

        ["blog"] : {
            en: "Blog",
            de: "Blog",
            ja: "TODO"
        }
    }
} satisfies Record<string, Record<string, Translation>>;

export const AnimationStateButtonTranslation = {
    en: "Play / Pause animation",
    de: "Animation ab / anstellen",
    ja: "TODO"
} satisfies Translation;