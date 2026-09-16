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
});
