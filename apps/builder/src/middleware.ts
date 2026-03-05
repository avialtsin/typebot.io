import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const AUTO_LOGIN_ENABLED =
  process.env.TYPEBOT_AUTO_LOGIN === "true";
const AUTO_SESSION_TOKEN =
  process.env.TYPEBOT_AUTO_SESSION_TOKEN ?? "";

export function middleware(req: NextRequest) {
  const { pathname, locale, defaultLocale, searchParams } = req.nextUrl;

  const isSecure = req.nextUrl.protocol === "https:";
  const isMostLikelySignedIn = Boolean(
    req.cookies.get("__Secure-authjs.session-token") ??
      req.cookies.get("authjs.session-token"),
  );

  // Auto-login: set session cookie if not present
  if (AUTO_LOGIN_ENABLED && AUTO_SESSION_TOKEN && !isMostLikelySignedIn) {
    const url = req.nextUrl.clone();
    url.pathname =
      locale && locale !== defaultLocale ? `/${locale}/typebots` : "/typebots";
    url.searchParams.delete("callbackUrl");
    url.searchParams.delete("redirectPath");

    const response = NextResponse.redirect(url);
    const cookieName = isSecure
      ? "__Secure-authjs.session-token"
      : "authjs.session-token";
    response.cookies.set(cookieName, AUTO_SESSION_TOKEN, {
      path: "/",
      httpOnly: true,
      secure: isSecure,
      sameSite: "lax",
      maxAge: 10 * 365 * 24 * 60 * 60, // 10 years
    });
    return response;
  }

  if (pathname === "/") {
    const toSignedIn =
      locale && locale !== defaultLocale ? `/${locale}/typebots` : "/typebots";
    const toSignin =
      locale && locale !== defaultLocale ? `/${locale}/signin` : "/signin";

    const url = req.nextUrl.clone();
    url.pathname = isMostLikelySignedIn ? toSignedIn : toSignin;

    return NextResponse.redirect(url);
  } else if (pathname === "/typebots") {
    const callbackUrl = searchParams.get("callbackUrl");
    const redirectPath = sanitizeRedirectPath(
      searchParams.get("redirectPath") ??
        (callbackUrl
          ? new URL(callbackUrl).searchParams.get("redirectPath")
          : undefined),
    );
    if (!redirectPath) return NextResponse.next();
    const url = req.nextUrl.clone();
    url.pathname = redirectPath;
    url.searchParams.delete("callbackUrl");
    url.searchParams.delete("redirectPath");
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

function sanitizeRedirectPath(
  redirectPath: string | null | undefined,
): string | null {
  if (!redirectPath) return null;

  try {
    // Prevent absolute URLs
    const url = new URL(redirectPath, "http://dummy"); // base needed for parsing
    if (url.origin !== "http://dummy") return null; // absolute external URL → reject

    const safePath = url.pathname + url.search + url.hash;

    return safePath;
  } catch {
    return null;
  }
}

export const config = {
  matcher: ["/", "/typebots"],
};
