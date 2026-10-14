// @ts-check
import { defineConfig } from 'astro/config';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

import mdx from '@astrojs/mdx';

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

  devToolbar: {
      enabled: false
  },

  site: 'https://chroma-void.com',

  i18n: {
      defaultLocale: 'en',
      locales: ['en', 'de', 'jp'],
      routing: {
          prefixDefaultLocale: false // /foo instead of /en/foo
      },
  },

  integrations: [mdx()]
});