import { render, screen } from "@testing-library/react";

import { clientEnv } from "~/config/client-env";
import { ErrorBoundary } from "~/root";
import type { Route } from "./+types/root";

// react-router 8 ships only ES modules, and Jest runs tests as CommonJS, so the
// real package cannot be loaded here: Jest stops with "Must use import to load
// ES Module". This factory replaces it without ever loading it. ErrorBoundary
// uses only isRouteErrorResponse, copied from react-router 8.3.1
// (dist/production/lib/router/utils.js); the document components the other
// exports of root.tsx render are not needed by these tests.
jest.mock("react-router", () => ({
  isRouteErrorResponse: (error: unknown) => {
    const candidate = error as Record<string, unknown> | null | undefined;
    return (
      candidate != null &&
      typeof candidate.status === "number" &&
      typeof candidate.statusText === "string" &&
      typeof candidate.internal === "boolean" &&
      "data" in candidate
    );
  },
}));

// The boundary only reads `error`; the other props React Router passes are
// irrelevant to what it renders.
function renderBoundary(error: unknown) {
  const props = { error } as Route.ErrorBoundaryProps;
  render(<ErrorBoundary {...props} />);
}

function thrownError() {
  const error = new Error("Something broke");
  error.stack = "Error: Something broke\n    at the component that threw";
  return error;
}

describe("ErrorBoundary", () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("shows the error message and stack trace in development", () => {
    jest.replaceProperty(clientEnv, "DEV", true);

    renderBoundary(thrownError());

    expect(screen.getByText("Something broke")).toBeInTheDocument();
    expect(screen.getByText(/at the component that threw/)).toBeInTheDocument();
  });

  it("hides the error message and stack trace outside development", () => {
    jest.replaceProperty(clientEnv, "DEV", false);

    renderBoundary(thrownError());

    expect(
      screen.getByText("An unexpected error occurred."),
    ).toBeInTheDocument();
    expect(screen.queryByText("Something broke")).not.toBeInTheDocument();
    expect(
      screen.queryByText(/at the component that threw/),
    ).not.toBeInTheDocument();
  });
});
