import React from 'react';
import { Quote, Sparkles } from 'lucide-react';
import { aboutMe, philosophy } from '../data/mock';

const About = () => {
  return (
    <section id="about" className="py-24 bg-[#1a1c1b] relative">
      {/* Decorative Elements */}
      <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#3f4816] to-transparent" />
      
      <div className="max-w-7xl mx-auto px-6 lg:px-10">
        {/* Section Header */}
        <div className="mb-16">
          <span className="text-[#d9fb06] text-sm font-semibold uppercase tracking-widest">About Me</span>
          <h2 className="text-4xl md:text-5xl font-black text-[#f5f5f4] mt-4 leading-tight">
            Building Cloud Infrastructure<br />
            <span className="text-[#888680]">That Actually Works</span>
          </h2>
        </div>

        <div className="grid lg:grid-cols-5 gap-12">
          {/* Main Content */}
          <div className="lg:col-span-3 space-y-8">
            {/* Intro */}
            <p className="text-xl text-[#f5f5f4] leading-relaxed">
              {aboutMe.intro}
            </p>

            {/* Highlight Box */}
            <div className="p-6 bg-[#302f2c] border-l-4 border-[#d9fb06] rounded-r-xl">
              <p className="text-lg text-[#f5f5f4] leading-relaxed">
                {aboutMe.highlight}
              </p>
            </div>

            {/* Philosophy Quote */}
            <div className="flex gap-4 pt-4">
              <Quote className="text-[#d9fb06] flex-shrink-0 mt-1" size={24} />
              <blockquote className="text-lg text-[#888680] italic leading-relaxed">
                {aboutMe.philosophy}
              </blockquote>
            </div>
          </div>

          {/* Core Philosophy Cards */}
          <div className="lg:col-span-2 space-y-4">
            <div className="flex items-center gap-2 mb-6">
              <Sparkles className="text-[#d9fb06]" size={20} />
              <h3 className="text-lg font-semibold text-[#f5f5f4]">Technical Philosophy</h3>
            </div>
            
            {philosophy.slice(0, 4).map((item, index) => (
              <div
                key={item.id}
                className="p-4 bg-[#302f2c] border border-[#3f4816]/50 rounded-xl hover:border-[#d9fb06]/30 transition-all duration-300 group"
              >
                <div className="flex items-start gap-3">
                  <span className="text-[#d9fb06] font-mono text-sm mt-0.5">0{index + 1}</span>
                  <div>
                    <h4 className="text-[#f5f5f4] font-semibold mb-1 group-hover:text-[#d9fb06] transition-colors">
                      {item.title}
                    </h4>
                    <p className="text-sm text-[#888680] leading-relaxed">
                      {item.description}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Expertise Tags */}
        <div className="mt-16 pt-12 border-t border-[#3f4816]/50">
          <p className="text-sm text-[#888680] uppercase tracking-wider mb-6">Core Expertise</p>
          <div className="flex flex-wrap gap-3">
            {[
              'AWS', 'Azure', 'Kubernetes', 'Terraform', 'CI/CD', 'HIPAA', 'SOC 2', 
              'Cost Optimization', 'Security Automation', 'GitOps', 'Infrastructure as Code'
            ].map((tag) => (
              <span
                key={tag}
                className="px-4 py-2 bg-[#302f2c] text-[#f5f5f4] text-sm font-medium rounded-full border border-[#3f4816]/50 hover:border-[#d9fb06]/50 hover:text-[#d9fb06] transition-all cursor-default"
              >
                {tag}
              </span>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
};

export default About;
