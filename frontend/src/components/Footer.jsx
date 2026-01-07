import React from 'react';
import { Linkedin, Mail, MapPin, ArrowUp } from 'lucide-react';
import { personalInfo } from '../data/mock';

const Footer = () => {
  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const currentYear = new Date().getFullYear();

  const footerLinks = [
    { label: 'About', href: '#about' },
    { label: 'Services', href: '#services' },
    { label: 'Projects', href: '#projects' },
    { label: 'Experience', href: '#experience' },
    { label: 'Contact', href: '#contact' }
  ];

  const scrollToSection = (e, href) => {
    e.preventDefault();
    const element = document.querySelector(href);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <footer className="bg-[#1a1c1b] border-t border-[#3f4816]/50">
      <div className="max-w-7xl mx-auto px-6 lg:px-10">
        {/* Main Footer */}
        <div className="py-16 grid md:grid-cols-3 gap-12">
          {/* Brand */}
          <div>
            <a
              href="#"
              className="text-[#d9fb06] font-bold text-2xl tracking-tight"
            >
              HN<span className="text-[#f5f5f4]">.dev</span>
            </a>
            <p className="text-[#888680] mt-4 leading-relaxed text-sm">
              DevOps Engineer specializing in cloud infrastructure, 
              security compliance, and cost optimization. Building 
              systems that scale.
            </p>
            <div className="flex items-center gap-4 mt-6">
              <a
                href={personalInfo.linkedin}
                target="_blank"
                rel="noopener noreferrer"
                className="p-2 bg-[#302f2c] rounded-lg text-[#888680] hover:text-[#d9fb06] hover:bg-[#3f4816]/30 transition-all"
              >
                <Linkedin size={20} />
              </a>
              <a
                href={`mailto:${personalInfo.email}`}
                className="p-2 bg-[#302f2c] rounded-lg text-[#888680] hover:text-[#d9fb06] hover:bg-[#3f4816]/30 transition-all"
              >
                <Mail size={20} />
              </a>
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h4 className="text-[#f5f5f4] font-semibold mb-4">Quick Links</h4>
            <ul className="space-y-3">
              {footerLinks.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    onClick={(e) => scrollToSection(e, link.href)}
                    className="text-[#888680] hover:text-[#d9fb06] text-sm transition-colors"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Contact Info */}
          <div>
            <h4 className="text-[#f5f5f4] font-semibold mb-4">Contact</h4>
            <div className="space-y-3">
              <div className="flex items-center gap-3 text-[#888680] text-sm">
                <Mail size={16} className="text-[#d9fb06]" />
                <span>{personalInfo.email}</span>
              </div>
              <div className="flex items-center gap-3 text-[#888680] text-sm">
                <MapPin size={16} className="text-[#d9fb06]" />
                <span>{personalInfo.location}</span>
              </div>
            </div>

            {/* CTA */}
            <a
              href="#contact"
              onClick={(e) => scrollToSection(e, '#contact')}
              className="inline-flex items-center gap-2 bg-[#d9fb06] text-[#1a1c1b] px-6 py-3 rounded-full font-semibold text-sm mt-6 hover:opacity-90 transition-all hover:scale-[1.02]"
            >
              <Mail size={16} />
              Get in Touch
            </a>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="py-6 border-t border-[#3f4816]/50 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-[#888680] text-sm">
            © {currentYear} Hansen Nkefor. All rights reserved.
          </p>
          <button
            onClick={scrollToTop}
            className="flex items-center gap-2 text-[#888680] hover:text-[#d9fb06] text-sm transition-colors"
          >
            Back to top
            <ArrowUp size={16} />
          </button>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
