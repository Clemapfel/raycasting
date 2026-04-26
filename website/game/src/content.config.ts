// src/content/config.ts
import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";
import { glslLoader } from "./shader-loader.ts";

const posts = defineCollection({
    loader: glob({ pattern: "*.md", base: "./src/content/posts" }),
    schema: z.object({
        title: z.string(),
        slug: z.string()
    })
});

const shaders = defineCollection({
    loader: glslLoader({ base: './src/content/shaders' }),
    schema: z.object({
        id: z.string(),
    }),
});

export const collections = {
    posts,
    shaders
};

