import React from "react";
import "./App.css";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Header from "./components/Header";
import Hero from "./components/Hero";
import About from "./components/About";
import Services from "./components/Services";
import Projects from "./components/Projects";
import Experience from "./components/Experience";
import Skills from "./components/Skills";
import Contact from "./components/Contact";
import Footer from "./components/Footer";

const PortfolioPage = () => {
  return (
    <div className="min-h-screen bg-[#1a1c1b]">
      <Header />
      <main>
        <Hero />
        <About />
        <Services />
        <Projects />
        <Experience />
        <Skills />
        <Contact />
      </main>
      <Footer />
    </div>
  );
};

function App() {
  return (
    <div className="App">
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<PortfolioPage />} />
        </Routes>
      </BrowserRouter>
    </div>
  );
}

export default App;
