import { render, screen, within } from "@testing-library/react";

import { SiteShell } from "~/components/site-shell";

describe("SiteShell", () => {
  it("renders its heading as the page's level-one heading", () => {
    render(<SiteShell heading="Tintara Lab">Contenido</SiteShell>);

    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Tintara Lab",
    );
  });

  it("renders its children inside the main landmark", () => {
    render(
      <SiteShell heading="Tintara Lab">
        <p>Contenido de prueba</p>
      </SiteShell>,
    );

    const main = screen.getByRole("main");

    expect(within(main).getByText("Contenido de prueba")).toBeInTheDocument();
  });
});
