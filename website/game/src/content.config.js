import { defineCollection } from 'astro:content';
import { glob, file } from 'astro/loaders';
import { z } from 'astro/zod';

const blog = defineCollection({
    loader: glob({ base: './src/content/posts', pattern: '**/*.{md,mdx}' }),
    schema: z.object({
        title: z.string(),
        description: z.string(),
    }),
});

export const collections = {
    blog
};