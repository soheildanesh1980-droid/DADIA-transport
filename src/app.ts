import tripsRouter from "./modules/trips/index.js";
import express from "express";
import pickupRouter from "./modules/pickup/index.js";
import movingRouter from "./modules/moving/index.js";
import heavyTruckRouter from "./modules/heavy-truck/index.js";
import courierRouter from "./modules/courier/index.js";

import authRouter from "./modules/auth/index.js";
import authProtectedRouter from "./routes/auth-protected.js";
import healthRouter from "./routes/health.js";
import passengerRouter from "./modules/passenger/index.js";
import driverRouter from "./modules/driver/index.js";
import adminRouter from "./modules/admin/index.js";
import mapsRouter from "./modules/maps/index.js";
import pricingRouter from "./modules/pricing/index.js";
import globalRouter from "./modules/global/index.js";
import paymentRouter from "./modules/payment/index.js";
import earningsRouter from "./modules/earnings/index.js";
import notificationsRouter from "./modules/notifications/index.js";
import ratingRouter from "./modules/rating/index.js";
import supportRouter from "./modules/support/index.js";
import vehiclesRouter from "./modules/vehicles/index.js";
import documentsRouter from "./modules/documents/index.js";

export const app = express();

app.use(express.json());

app.use(healthRouter);

app.use("/passenger", passengerRouter);
app.use("/driver", driverRouter);
app.use("/admin", adminRouter);
app.use("/auth", authRouter);
app.use("/auth-protected", authProtectedRouter);

export default app;

app.use("/trips", tripsRouter);
app.use("/maps", mapsRouter);
app.use("/pricing", pricingRouter);
app.use("/global", globalRouter);
app.use("/payment", paymentRouter);
app.use("/earnings", earningsRouter);
app.use("/notifications", notificationsRouter);
app.use("/rating", ratingRouter);
app.use("/support", supportRouter);
app.use("/vehicles", vehiclesRouter);
app.use("/documents", documentsRouter);
app.use("/courier", courierRouter);
app.use("/pickup", pickupRouter);
app.use("/moving", movingRouter);
app.use("/heavy-truck", heavyTruckRouter);

