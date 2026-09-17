import { SiteShell } from "~/components/site-shell";

export function meta() {
  return [{ title: "Tintara Lab" }];
}

export default function Home() {
  return (
    <SiteShell heading="Tintara Lab">
      <p>Sitio en construcción.</p>
    </SiteShell>
  );
}
