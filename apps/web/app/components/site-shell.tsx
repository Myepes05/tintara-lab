import type { ReactNode } from "react";

interface SiteShellProps {
  /** Rendered as the page's only level-one heading. */
  heading: string;
  children: ReactNode;
}

/**
 * The outer frame of a page: one main landmark and one level-one heading.
 *
 * Deliberately unstyled beyond spacing. The palette, typography and layout of
 * the real site come from the mockups in a later feature, and guessing at them
 * here would mean writing code that has to be thrown away.
 */
export function SiteShell({ heading, children }: SiteShellProps) {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col gap-6 p-8">
      <h1 className="text-3xl font-semibold">{heading}</h1>
      {children}
    </main>
  );
}
