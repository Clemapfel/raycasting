declare module "webgl-debug" {
    export function makeDebugContext(
        context: WebGL2RenderingContext,
        opt_onErrorFunc?: (err: number, func_name: string, args: IArguments) => void,
    ): WebGL2RenderingContext;
}