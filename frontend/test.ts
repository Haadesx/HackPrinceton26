import { useNavigate } from "react-router-dom";
function Test() {
  const navigate = useNavigate();
  navigate("/lattice", { viewTransition: true });
}
