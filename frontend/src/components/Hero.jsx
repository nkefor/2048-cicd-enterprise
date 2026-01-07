import React from 'react';
import { ArrowDown, MapPin, Cloud, Server, Shield } from 'lucide-react';
import { personalInfo, stats } from '../data/mock';

const Hero = () => {
  const scrollToAbout = () => {
    const element = document.querySelector('#about');
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <section className="min-h-screen bg-[#1a1c1b] relative overflow-hidden flex items-center">
      {/* Background Grid Pattern */}
      <div className="absolute inset-0 opacity-[0.03]">
        <div className="absolute inset-0" style={{
          backgroundImage: `linear-gradient(#d9fb06 1px, transparent 1px), linear-gradient(90deg, #d9fb06 1px, transparent 1px)`,
          backgroundSize: '60px 60px'
        }} />
      </div>

      {/* Floating Elements */}
      <div className="absolute top-32 right-20 text-[#3f4816] opacity-20 animate-pulse">
        <Cloud size={120} strokeWidth={1} />
      </div>
      <div className="absolute bottom-40 left-16 text-[#3f4816] opacity-20 animate-pulse" style={{ animationDelay: '1s' }}>
        <Server size={80} strokeWidth={1} />
      </div>
      <div className="absolute top-1/2 right-40 text-[#3f4816] opacity-20 animate-pulse" style={{ animationDelay: '2s' }}>
        <Shield size={60} strokeWidth={1} />
      </div>

      <div className="max-w-7xl mx-auto px-6 lg:px-10 py-32 relative z-10 w-full">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left Content */}
          <div className="space-y-8">
            {/* Status Badge */}
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-[#302f2c] rounded-full border border-[#3f4816]/50">
              <span className="w-2 h-2 bg-[#d9fb06] rounded-full animate-pulse" />
              <span className="text-[#888680] text-sm font-medium">Available for opportunities</span>
            </div>

            {/* Name */}
            <h1 className="text-5xl md:text-6xl lg:text-7xl font-black text-[#f5f5f4] leading-[0.9] tracking-tight">
              {personalInfo.name.split(' ')[0]}
              <br />
              <span className="text-[#d9fb06]">{personalInfo.name.split(' ')[1]}</span>
            </h1>

            {/* Title */}
            <div className="space-y-2">
              <p className="text-xl md:text-2xl text-[#f5f5f4] font-medium">
                DevOps Engineer
              </p>
              <p className="text-lg text-[#888680]">
                Cloud Architect • Multi-Cloud Infrastructure Specialist
              </p>
            </div>

            {/* Location */}
            <div className="flex items-center gap-2 text-[#888680]">
              <MapPin size={18} className="text-[#d9fb06]" />
              <span>{personalInfo.location}</span>
            </div>

            {/* Tagline */}
            <p className="text-lg text-[#888680] max-w-lg leading-relaxed">
              {personalInfo.tagline}
            </p>

            {/* CTAs */}
            <div className="flex flex-wrap gap-4 pt-4">
              <a
                href="#projects"
                onClick={(e) => {
                  e.preventDefault();
                  document.querySelector('#projects')?.scrollIntoView({ behavior: 'smooth' });
                }}
                className="inline-flex items-center gap-2 bg-[#d9fb06] text-[#1a1c1b] px-8 py-4 rounded-full font-semibold text-base hover:opacity-90 transition-all duration-200 hover:scale-[1.02]"
              >
                View Projects
              </a>
              <a
                href="#contact"
                onClick={(e) => {
                  e.preventDefault();
                  document.querySelector('#contact')?.scrollIntoView({ behavior: 'smooth' });
                }}
                className="inline-flex items-center gap-2 bg-transparent text-[#d9fb06] px-8 py-4 rounded-full font-semibold text-base border border-[#d9fb06] hover:bg-[#d9fb06] hover:text-[#1a1c1b] transition-all duration-200"
              >
                Contact Me
              </a>
            </div>
          </div>

          {/* Right - Stats Grid */}
          <div className="grid grid-cols-2 gap-4">
            {stats.map((stat, index) => (
              <div
                key={stat.id}
                className={`p-6 bg-[#302f2c] border border-[#3f4816]/50 rounded-2xl transition-all duration-300 hover:border-[#d9fb06]/30 hover:bg-[#302f2c]/80 ${
                  index === 0 ? 'lg:col-span-2' : ''
                }`}
              >
                <div className={`${index === 0 ? 'text-5xl md:text-6xl' : 'text-4xl md:text-5xl'} font-black text-[#d9fb06] mb-2`}>
                  {stat.value}
                </div>
                <div className="text-[#888680] text-sm font-medium uppercase tracking-wider">
                  {stat.label}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Scroll Indicator */}
        <button
          onClick={scrollToAbout}
          className="absolute bottom-10 left-1/2 -translate-x-1/2 text-[#888680] hover:text-[#d9fb06] transition-colors animate-bounce"
        >
          <ArrowDown size={24} />
        </button>
      </div>
    </section>
  );
};

export default Hero;
