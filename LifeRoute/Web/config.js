// Public, non-secret integration configuration only.
// Never commit OAuth client secrets, CentralReach tokens, or Apple private keys here.
window.LifeRouteConfig = {
  googleCalendar: {
    enabled: false,
    clientId: "",
    scopes: ["https://www.googleapis.com/auth/calendar.readonly"],
    mode: "read-only"
  },
  centralReach: {
    enabled: false,
    baseURL: "https://partners-api.centralreach.com/enterprise/v1/",
    mode: "read-only",
    scheduleReadEndpoints: {
      byProvider: "schedule/events/by-provider",
      byAppointmentWith: "schedule/events/by-appointment-with"
    }
  }
};
