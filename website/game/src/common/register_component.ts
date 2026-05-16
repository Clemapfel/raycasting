/** **/
export function register(name: string, type: CustomElementConstructor) {
    const callback = () => {
        if (!customElements.get(name))
            customElements.define(name, type);
    }
    callback();
    document.addEventListener("astro:page-load", callback, { once: false });
}
