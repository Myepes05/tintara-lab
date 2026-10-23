import {
  DEFAULT_PUBLIC_API_BASE_URL,
  readPublicConfig,
} from "~/config/public-config";

describe("readPublicConfig", () => {
  it("returns the configured public API base URL", () => {
    const config = readPublicConfig({
      VITE_PUBLIC_API_BASE_URL: "https://api.tintaralab.com",
    });

    expect(config.apiBaseUrl).toBe("https://api.tintaralab.com");
  });

  it("falls back to the development default when the variable is absent", () => {
    expect(readPublicConfig({}).apiBaseUrl).toBe(DEFAULT_PUBLIC_API_BASE_URL);
  });

  it("falls back to the development default when the variable is blank", () => {
    expect(
      readPublicConfig({ VITE_PUBLIC_API_BASE_URL: "   " }).apiBaseUrl,
    ).toBe(DEFAULT_PUBLIC_API_BASE_URL);
  });

  it("points the development default at the local Rails server", () => {
    expect(DEFAULT_PUBLIC_API_BASE_URL).toBe("http://localhost:3000");
  });
});
