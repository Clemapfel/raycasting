import { GLContext } from "./gl_context.ts";

/** **/
export abstract class GLResource {
    private is_allocated = false;
    protected context : GLContext;

    /** **/
    constructor(context : GLContext) {
        this.context = context;
    }

    /** **/
    public allocate() {
        this.is_allocated = true;
    };

    /** **/
    public deallocate() {
        this.is_allocated = false;
    };

    /** **/
    public getIsAllocated() {
        return this.is_allocated;
    }
}
