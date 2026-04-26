import type { Loader } from 'astro/loaders';
import { promises as fs } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, relative } from 'node:path';

export function glslLoader(options: { base: string | URL }): Loader {
    return {
        name: 'glsl-loader',
        load: async ({ store, logger, watcher }) => {
            // 1. Resolve the base directory
            const baseDir = typeof options.base === 'string'
                ? new URL(options.base, `file://${process.cwd()}/`)
                : options.base;

            const dirPath = fileURLToPath(baseDir);

            // Helper function to read and store a single GLSL file
            const syncFile = async (filePath: string) => {
                try {
                    const code = await fs.readFile(filePath, 'utf-8');
                    // Create a stable ID (e.g., "utils/noise" for "utils/noise.glsl")
                    const id = relative(dirPath, filePath).replace(/\.glsl$/, '').replace(/\\/g, '/');

                    store.set({
                        id,
                        body: code,          // Store the raw GLSL code in the body
                        data: { id },        // Required by schema
                        filePath,            // Helps Astro track the file internally
                    });
                } catch (err) {
                    logger.error(`Failed to load shader: ${filePath}`);
                }
            };

            // Helper to recursively find all .glsl files
            const loadDirectory = async (dir: string) => {
                try {
                    const entries = await fs.readdir(dir, { withFileTypes: true });
                    for (const entry of entries) {
                        const fullPath = resolve(dir, entry.name);
                        if (entry.isDirectory()) {
                            await loadDirectory(fullPath);
                        } else if (entry.name.endsWith('.glsl')) {
                            await syncFile(fullPath);
                        }
                    }
                } catch (err) {
                    logger.warn(`Could not read directory: ${dir}`);
                }
            };

            // 2. Perform the initial load
            store.clear(); // Ensure clean slate on restart
            await loadDirectory(dirPath);
            logger.info('GLSL files loaded successfully.');

            // 3. Set up Hot Module Replacement (HMR) for dev mode
            if (watcher) {
                watcher.on('add', async (path) => {
                    if (path.startsWith(dirPath) && path.endsWith('.glsl')) await syncFile(path);
                });
                watcher.on('change', async (path) => {
                    if (path.startsWith(dirPath) && path.endsWith('.glsl')) await syncFile(path);
                });
                watcher.on('unlink', (path) => {
                    if (path.startsWith(dirPath) && path.endsWith('.glsl')) {
                        const id = relative(dirPath, path).replace(/\.glsl$/, '').replace(/\\/g, '/');
                        store.delete(id); // Remove from collection if deleted
                    }
                });
            }
        },
    };
}