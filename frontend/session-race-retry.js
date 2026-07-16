/*
 * Session-rotation race retry shim.
 *
 * The backend (ethiopiaemr-custom-module's SessionFixationProtectionFilter) rotates the HTTP
 * session id on the first authenticated request, mitigating session fixation (CWE-384). Right
 * after login the SPA fires several API requests concurrently, all still carrying the
 * pre-rotation session cookie; any of them that reaches the server after the rotation is
 * rejected with HTTP 401 (webservices.rest and fhir2 both validate the presented session id),
 * which used to bounce the user back to the login page.
 *
 * This shim wraps window.fetch and, for OpenMRS API calls only, retries a 401 response a bounded
 * number of times with increasing delays. By retry time the browser has normally processed the
 * Set-Cookie from the rotating response, so the retry carries the current session cookie and
 * succeeds. The caller only ever sees the final response, so no application code needs to change.
 *
 * Non-race 401s (e.g. a genuinely expired session) still surface unchanged after the retries are
 * exhausted; the only cost there is a few seconds' delay before the usual redirect to login.
 *
 * This file is injected into the SPA's index.html <head> by the frontend Dockerfile, so it runs
 * before the app shell bootstraps and therefore wraps fetch before the first API call is made. It
 * is intentionally framework-independent: it does not care which @openmrs/esm-framework version
 * the app shell bundles.
 */
(function () {
  'use strict';

  if (window.__omrsSessionRaceRetryInstalled) {
    return;
  }
  window.__omrsSessionRaceRetryInstalled = true;

  // Bounded backoff. The last delay is generous on purpose: on a cold/busy server the rotating
  // response (the one whose Set-Cookie carries the new session id) can itself take seconds to
  // arrive, and retrying before it lands would just replay the stale cookie.
  var RETRY_DELAYS_MS = [400, 1600, 4000];

  var origFetch = window.fetch.bind(window);

  function delay(ms) {
    return new Promise(function (resolve) {
      setTimeout(resolve, ms);
    });
  }

  function isOpenmrsApiUrl(url) {
    return url.indexOf('/ws/rest/') !== -1 || url.indexOf('/ws/fhir') !== -1;
  }

  window.fetch = function (input, init) {
    var url = typeof input === 'string' ? input : (input && input.url) || '';
    var promise = origFetch(input, init);
    if (!isOpenmrsApiUrl(url)) {
      return promise;
    }

    function handleResponse(attempt) {
      return function (response) {
        var aborted = init && init.signal && init.signal.aborted;
        if (response.status === 401 && !aborted && attempt < RETRY_DELAYS_MS.length) {
          if (window.console && console.debug) {
            console.debug(
              'openmrs session-race-retry: 401 on ' + url + ', retry ' + (attempt + 1) + '/' + RETRY_DELAYS_MS.length
            );
          }
          return delay(RETRY_DELAYS_MS[attempt]).then(function () {
            return origFetch(input, init).then(handleResponse(attempt + 1));
          });
        }
        return response;
      };
    }

    return promise.then(handleResponse(0));
  };
})();
