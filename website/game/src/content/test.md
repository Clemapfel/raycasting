# Markdown Renderer — Astro Layout Template

# TEST

## Files

```
src/
  layouts/
    MarkdownPost.astro   ← the renderer layout
  pages/
    post.astro           ← example page showing usage
```

## How it works

> this is a block quote

`MarkdownPost.astro` is a full-page layout. It draws a warm parchment-colored card
(`--card-background`) centered over a dark textured page background
(`--page-background`). The card has fixed horizontal margins (`--card-padding-x`)
and a bottom gap so the dark background is visible beneath the post.

The `<slot />` inside the layout accepts any rendered markdown HTML.

---

## Usage with Astro Content Collections

```astro
---
// src/pages/posts/[slug].astro
import { getCollection, render } from 'astro:content';
import MarkdownPost from '../../layouts/MarkdownPost.astro';

export async function getStaticPaths() {
  const posts = await getCollection('posts');
  return posts.map(post => ({ params: { slug: post.slug }, props: { post } }));
}

const { post } = Astro.props;
const { Content } = await render(post);
---

<MarkdownPost title={post.data.title}>
  <Content />
</MarkdownPost>
```

## Usage with a raw Markdown file via import

```astro
---
// src/pages/my-post.astro
import MarkdownPost from '../layouts/MarkdownPost.astro';
import { Content } from '../content/my-post.md';
---

<MarkdownPost title="My Post">
  <Content />
</MarkdownPost>
```

---

## Customising dimensions

All dimensions are CSS custom properties on `:root` inside the layout:

| Variable                | Default   | Effect                                   |
|-------------------------|-----------|------------------------------------------|
| `--card-width`          | `720px`   | Maximum width of the text card           |
| `--card-padding-x`      | `56px`    | Left and right inner margin              |
| `--card-padding-top`    | `72px`    | Space above the first heading            |
| `--card-padding-bottom` | `80px`    | Space below the last line of text        |
| `--card-margin-top`     | `64px`    | Gap between the top of the viewport      |
| `--card-margin-bottom`  | `80px`    | Gap below the card (shows page bg)       |
| `--page-background`     | `#1a1612` | Page canvas color                        |
| `--card-background`     | `#f5f0e8` | Card fill color                          |
| `--accent`              | `#c8602a` | Link color, h2 rule, list markers        |

Override any of these in a `<style>` block inside the consuming page, or pass
them as inline styles on the wrapping element if you need per-post theming.