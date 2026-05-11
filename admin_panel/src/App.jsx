import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import Locations from './pages/Locations';
import Artifacts from './pages/Artifacts';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Dashboard />} />
          <Route path="users" element={<Users />} />
          <Route path="locations" element={<Locations />} />
          <Route path="artifacts" element={<Artifacts />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
