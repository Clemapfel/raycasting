// @ts-check
import { defineConfig } from 'astro/config';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

export default defineConfig({
    vite: {
        server: {
            watch: { // enable busy wait polling
                usePolling: true,
                interval: 17, // ms, 60 / 10 fps
            },
        },
    },

    markdown: {
        shikiConfig: {
            theme: 'css-variables', // use css variables instead of hardcoded for code style
        },
        remarkPlugins: [remarkMath],
        rehypePlugins: [rehypeKatex],
    },
});