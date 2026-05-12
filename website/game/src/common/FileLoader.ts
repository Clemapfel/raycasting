import type { Loader } from "astro/loaders";

// @ts-ignore
if (process == undefined)
    throw new Error("In FileLoader.ts: node is not installed, it is required to load files other than Markdown, MDX, Markdoc, JSON, YAML, TOML")

// @ts-ignore
import { promises as fs } from "node:fs";

// @ts-ignore
import { fileURLToPath } from "node:url";

// @ts-ignore
import { resolve, relative } from "node:path";

export function FileLoader(file_extension : string, options: { base: string | URL }): Loader {
    const loader_id = `FileLoader(${file_extension})`;

    if (file_extension.startsWith("."))
        throw new Error(`In ${loader_id}: file_extention parameter ${file_extension} may no start with a dot`);
    
    return {
        name: loader_id,
        load: async ({ store, logger, watcher }) => {
            // @ts-ignore
            const base_directory = typeof options.base === "string" ? new URL(options.base, `file://${process.cwd()}/`) : options.base;
            const prefix = fileURLToPath(base_directory);

            // create stable ID:  "utils/noise.file*" -> "utils/noise"
            const create_id = (path : string) => {
                return relative(prefix, path).replace(`.${file_extension}`, "").replace(/\\/g, "/");
            }

            // load a single file
            const load_file = async (path: string) => {
                try {
                    const code = await fs.readFile(path, "utf-8");
                    const id = create_id(path);
                    store.set({
                        id,
                        body: code,     // raw file content
                        data: { id },   // schema id
                        filePath: path, // needed to track file
                    });
                } catch (err) {
                    logger.error(`In ${loader_id}: failed to load shader at ${path}`);
                }
            };

            // load all files in a directory
            const load_directory = async (directory: string) => {
                try {
                    const entries = await fs.readdir(directory, { withFileTypes: true });
                    for (const entry of entries) {
                        const full_path = resolve(directory, entry.name);
                        if (entry.isDirectory()) {
                            await load_directory(full_path);
                        } else if (entry.name.endsWith(file_extension)) {
                            await load_file(full_path);
                        }
                    }
                } catch (err) {
                    logger.warn(`In ${loader_id}: failed to read directory at ${directory}`);
                }
            };

            // clear cache, then load all files
            store.clear();
            await load_directory(prefix);
            logger.info(`In ${loader_id}: files loaded succesfully`);

            // watchers
            if (watcher) {
                const is_filetype = (path : string) => {
                    return path.startsWith(prefix) && path.endsWith(`.${file_extension}`)
                }

                watcher.add(prefix);

                watcher.on("add", async (path) => {
                    if (is_filetype(path)) await load_file(path);
                });

                watcher.on("change", async (path) => {
                    if (is_filetype(path)) await load_file(path);
                });

                watcher.on("unlink", (path) => {
                    if (is_filetype(path)) {
                        const id = create_id(path);
                        store.delete(id);
                    }
                });
            }
        },
    };
}