export const ANIMATION_STATE = "--global-animation-state";
export const ANIMATION_STATE_ACTIVE = "running";
export const ANIMATION_STATE_INACTIVE = "paused";

export function getIsAnimationPaused() {
    return document.documentElement.style.getPropertyValue(ANIMATION_STATE) === ANIMATION_STATE_INACTIVE;
}

export function setIsAnimationPaused(paused: boolean) {
    document.documentElement.style.setProperty(
        ANIMATION_STATE,
        paused ? ANIMATION_STATE_INACTIVE : ANIMATION_STATE_ACTIVE
    );
}