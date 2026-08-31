import {initializeApp} from "firebase-admin/app";
import {setGlobalOptions} from "firebase-functions";

initializeApp();

setGlobalOptions({
  maxInstances: 10,
  region: "southamerica-east1",
});

export {
  createAcademyUser,
  syncAcademyMemberProfiles,
} from "./create_academy_user";

export {
  updateAcademyUser,
} from "./update_academy_user";
export {
  selfRegisterUser,
} from "./self_register_user";
