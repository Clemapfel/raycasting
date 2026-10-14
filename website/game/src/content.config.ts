// src/content/config.ts
import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";
import { FileLoader } from "./common/file_loader.ts";

export const collections = {
    posts: defineCollection({
        loader: glob({ pattern: "*.md", base: "./src/content/posts" }),
        schema: z.object({
            title: z.string(),
            slug: z.string(),
            date: z.string(),
            shader: z.string()
        })
    }),

    pages: defineCollection({
        loader: glob({ pattern: "*.{md,mdx}", base: "./src/content/pages/en" }),
        schema: z.object({
            language: z.string(),
            shader: z.string()
        })
    }),

    shaders: defineCollection({
        loader: FileLoader("glsl", { base: "./src/content/shaders" }),
        schema: z.object({
            id: z.string()
        })
    })
};

