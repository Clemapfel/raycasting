// src/content/config.ts
import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";
import { FileLoader } from "./common/FileLoader.ts";

const posts = defineCollection({
    loader: glob({ pattern: "*.md", base: "./src/content/posts" }),
    schema: z.object({
        title: z.string(),
        slug: z.string(),
        date: z.string(),
        shader: z.string()
    })
});

const shaders = defineCollection({
    loader: FileLoader("glsl", { base: "./src/content/shaders" }),
    schema: z.object({
        id: z.string(),
    }),
});

export const collections = {
    posts,
    shaders
};

