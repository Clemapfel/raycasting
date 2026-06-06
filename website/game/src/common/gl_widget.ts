import { GLContext } from "./gl_context.ts";
import { Time, TimeUnit } from "./time.ts";
import { Vec2 } from "./vector.ts";

export abstract class GLWidget extends HTMLElement {
    protected context : GLContext;
    private native_canvas : HTMLCanvasElement;
    private delta : Time = new Time();

    protected async realize() : Promise<void> {}
    protected unrealize() : void {}
    protected draw() : void {}
    protected reformat(width: number, height: number) : void {}
    protected update(time_delta: Time) : void {}

    protected onMousePressed(x : number, y : number, event: MouseEvent) : void {}
    protected onMouseReleased(x : number, y : number, event: MouseEvent) : void {}
    protected onMouseMoved(x : number, y : number, event: MouseEvent) : void {}

    protected onMouseEnter(event: MouseEvent) : void {}
    protected onMouseLeave(event: MouseEvent) : void {}
    protected onMouseWheelMoved(event: WheelEvent) : void {}
    protected onKeyPressed(event: KeyboardEvent) : void {}
    protected onKeyReleased(event: KeyboardEvent) : void {}
    protected onFocusGained(event: FocusEvent) : void {}
    protected onFocusLost(event: FocusEvent) : void {}

    public isRealized() : boolean {
        return this.is_realized;
    }

    public getSize() : Vec2 {
        return this.size.clone();
    }

    public getWidth() : number {
        return this.size.x;
    }

    public getHeight() : number {
        return this.size.y;
    }

    constructor() {
        super();

        this.resize_observer = new ResizeObserver(entries => {
            for (const entry of entries) {
                let width = 0;
                let height = 0;

                if (entry.devicePixelContentBoxSize) {
                    width = entry.devicePixelContentBoxSize[0].inlineSize;
                    height = entry.devicePixelContentBoxSize[0].blockSize;
                } else {
                    const dpr = window.devicePixelRatio;
                    width = Math.ceil(entry.contentRect.width * dpr);
                    height = Math.ceil(entry.contentRect.height * dpr);
                }

                this.native_canvas.width = width;
                this.native_canvas.height = height;

                if (this.context && this.context.isValid())
                    this.context._notify_size_changed(width, height);

                this.size.x = width;
                this.size.y = height;
                this.reformat(width, height);
                this.draw();
            }
        });

        // only connect events if child implements super functions
        const prototype = GLWidget.prototype;
        if (this.onMousePressed !== prototype.onMousePressed)
            this.addEventListener("mousedown", this.handle_mouse_pressed);

        if (this.onMouseReleased !== prototype.onMouseReleased)
            this.addEventListener("mouseup", this.handle_mouse_released);

        if (this.onMouseEnter !== prototype.onMouseEnter)
            this.addEventListener("mouseenter", this.handle_mouse_enter);

        if (this.onMouseLeave !== prototype.onMouseLeave)
            this.addEventListener("mouseleave", this.handle_mouse_leave);

        if (this.onMouseMoved !== prototype.onMouseMoved)
            this.addEventListener("mousemove", this.handle_mouse_moved);

        if (this.onMouseWheelMoved !== prototype.onMouseWheelMoved)
            this.addEventListener("wheel", this.handle_mouse_wheel_moved);

        if (this.onKeyPressed !== prototype.onKeyPressed)
            this.addEventListener("keydown", this.handle_key_pressed);

        if (this.onKeyReleased !== prototype.onKeyReleased)
            this.addEventListener("keyup", this.handle_key_released);

        if (this.onFocusGained !== prototype.onFocusGained)
            this.addEventListener("focus", this.handle_focus);

        if (this.onFocusLost !== prototype.onFocusLost)
            this.addEventListener("blur", this.handle_blur);
    }

    private is_realized : boolean = false;
    private resize_observer : ResizeObserver;
    private size: Vec2 = new Vec2(0, 0);
    private frame_identifier? : number;
    private last_timestamp? : DOMHighResTimeStamp = performance.now();

    public async connectedCallback() {
        const internal_canvas = this.querySelector("canvas");
        if (internal_canvas === null) {
            throw new Error("GLWidget: No canvas element found within the custom element.");
        }

        this.native_canvas = internal_canvas;
        this.context = new GLContext(this.native_canvas);

        this.resize_observer.observe(this, { box: "device-pixel-content-box" });

        await this.realize(); // yield to browser
        this.is_realized = true;
        this.frame_identifier = requestAnimationFrame(this.on_request_animation_frame);
    }

    public disconnectedCallback() {
        this.resize_observer.disconnect();
        if (this.frame_identifier !== undefined) {
            cancelAnimationFrame(this.frame_identifier);
        }
        if (this.is_realized) {
            this.unrealize();
        }
    }

    private on_request_animation_frame = (timestamp: DOMHighResTimeStamp) => {
        if (!this.is_realized) return;
        const delta = this.last_timestamp === undefined ? 0 : (timestamp - this.last_timestamp);
        this.last_timestamp = timestamp;
        this.delta.from(delta, TimeUnit.MILLISECONDS);
        this.update(this.delta);
        this.draw();
        this.frame_identifier = requestAnimationFrame(this.on_request_animation_frame);
    }

    private to_local_position(event: MouseEvent): { x: number; y: number } {
        const rect = this.native_canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio ?? 1;
        return {
            x: (event.clientX - rect.left) * dpr,
            y: (event.clientY - rect.top) * dpr,
        };
    }

    private handle_mouse_pressed = (event: MouseEvent) => {
        const { x, y } = this.to_local_position(event);
        this.onMousePressed(x, y, event);
    };

    private handle_mouse_released = (event: MouseEvent) => {
        const { x, y } = this.to_local_position(event);
        this.onMouseReleased(x, y, event);
    };

    private handle_mouse_moved = (event: MouseEvent) => {
        const { x, y } = this.to_local_position(event);
        this.onMouseMoved(x, y, event);
    };

    private handle_mouse_enter = (event: MouseEvent) => this.onMouseEnter(event);
    private handle_mouse_leave = (event: MouseEvent) => this.onMouseLeave(event);
    private handle_mouse_wheel_moved = (event: WheelEvent) => this.onMouseWheelMoved(event);
    private handle_key_pressed = (event: KeyboardEvent) => this.onKeyPressed(event);
    private handle_key_released = (event: KeyboardEvent) => this.onKeyReleased(event);
    private handle_focus = (event: FocusEvent) => this.onFocusGained(event);
    private handle_blur = (event: FocusEvent) => this.onFocusLost(event);
}