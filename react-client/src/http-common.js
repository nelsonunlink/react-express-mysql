import axios from "axios";

export default axios.create({
  // Use a relative path so browser requests go to the same origin (Ingress),
  // which allows the Ingress to route /api/* → backend-service.
  baseURL: process.env.REACT_APP_API_URL || "/api",
  headers: {
    "Content-type": "application/json"
  }
});