import type { ServerEnv } from "~/config/env-types";
import { readServerConfig } from "~/config/server-config.server";

const completeEnv: ServerEnv = {
  API_INTERNAL_URL: "http://localhost:3000",
  API_INTERNAL_TOKEN: "a-development-token",
};

describe("readServerConfig", () => {
  it("returns the server-only values it was given", () => {
    const config = readServerConfig(completeEnv);

    expect(config).toEqual({
      apiInternalUrl: "http://localhost:3000",
      apiInternalToken: "a-development-token",
    });
  });

  it.each(["API_INTERNAL_URL", "API_INTERNAL_TOKEN"])(
    "throws an error naming %s when it is missing",
    (variable) => {
      const env: ServerEnv = { ...completeEnv };
      delete env[variable];

      expect(() => readServerConfig(env)).toThrow(variable);
    },
  );

  it.each(["API_INTERNAL_URL", "API_INTERNAL_TOKEN"])(
    "treats a blank %s as missing",
    (variable) => {
      const env: ServerEnv = { ...completeEnv, [variable]: "   " };

      expect(() => readServerConfig(env)).toThrow(variable);
    },
  );

  it("names every missing variable in one error", () => {
    expect(() => readServerConfig({})).toThrow(
      /API_INTERNAL_URL.*API_INTERNAL_TOKEN/s,
    );
  });

  it("trims surrounding whitespace from the values it returns", () => {
    const config = readServerConfig({
      API_INTERNAL_URL: " http://x ",
      API_INTERNAL_TOKEN: "\ta-development-token\n",
    });

    expect(config).toEqual({
      apiInternalUrl: "http://x",
      apiInternalToken: "a-development-token",
    });
  });
});

describe("getServerConfig", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    // A fresh copy of the module, so its cache starts empty in every test.
    jest.resetModules();
    process.env = {
      ...originalEnv,
      API_INTERNAL_URL: "http://first",
      API_INTERNAL_TOKEN: "first-token",
    };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("reads the process environment once and reuses the result", async () => {
    const { getServerConfig } = await import("~/config/server-config.server");

    const first = getServerConfig();
    process.env.API_INTERNAL_URL = "http://second";

    expect(getServerConfig()).toBe(first);
    expect(getServerConfig().apiInternalUrl).toBe("http://first");
  });
});
