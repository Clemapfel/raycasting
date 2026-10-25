import {
    getIsAnimationPaused,
    setIsAnimationPaused
} from "../common/state.ts";

export class AnimationStateButton extends HTMLElement {
    private button!: HTMLButtonElement;

    connectedCallback() {
        this.button = this.querySelector("button")!;
        this.setIsPaused(getIsAnimationPaused());
        this.button.addEventListener("click", this.onClick);
    }

    disconnectedCallback() {
        this.button?.removeEventListener("click", this.onClick);
    }

    private setIsPaused(paused: boolean) {
        this.button.setAttribute("aria-pressed", String(paused));
        this.button.setAttribute("aria-label", paused ? "Play animations" : "Pause animations");
        setIsAnimationPaused(paused);
    }

    private onClick = () => {
        this.setIsPaused(! getIsAnimationPaused());
    };
}