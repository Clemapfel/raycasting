---
title: My Blog Post
---

H1: The Grand Theory of Everything
This is a standard paragraph showing off your **body font** and general text color. If your container is working correctly, this text should wrap based on the width of the parent element rather than hitting a fixed pixel limit.

## H2: Mathematical Foundations
Here is an example of an inline formula: $E = mc^2$.

Below is a display formula featuring a complex integral to test your LaTeX rendering and the specific font/size variables you assigned to the `.katex` class:

$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
$$

### H3: Programming and Logic
You can also use inline code like `const astro = "awesome";` which should use your designated monospace font.

#### H4: Code Snippet Verification
The block below will test your Shiki syntax highlighting variables (`keyword`, `string`, `function`, etc.), the background color, and the border frame.

```typescript
// This is a comment to test --md-code-color-comment
function calculateArea(radius: number): number {
  const pi: number = 3.14159; // Constant color
  return pi * (radius ** 2);  // Function and Parameter colors
}

const message: string = "Hello, Astro!"; // String color
console.log(calculateArea(10));