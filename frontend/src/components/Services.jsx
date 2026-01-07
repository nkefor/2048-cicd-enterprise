import React from 'react';
import { Cloud, Settings, Shield, Activity, ArrowRight } from 'lucide-react';
import { services } from '../data/mock';

const iconMap = {
  'Cloud Infrastructure & Migration': Cloud,
  'DevOps & Automation': Settings,
  'Security & Compliance': Shield,
  'Reliability Engineering': Activity
};

const Services = () => {
  return (
    <section id="services" className="py-24 bg-[#302f2c]/30 relative">
      <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#3f4816] to-transparent" />
      
      <div className="max-w-7xl mx-auto px-6 lg:px-10">
        {/* Section Header */}
        <div className="mb-16">
          <span className="text-[#d9fb06] text-sm font-semibold uppercase tracking-widest">What I Do</span>
          <h2 className="text-4xl md:text-5xl font-black text-[#f5f5f4] mt-4 leading-tight">
            Engineering Excellence<br />
            <span className="text-[#888680]">At Every Layer</span>
          </h2>
        </div>

        {/* Services Grid */}
        <div className="grid md:grid-cols-2 gap-6">
          {services.map((service, index) => {
            const IconComponent = iconMap[service.title] || Cloud;
            return (
              <div
                key={service.id}
                className="group p-8 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-2xl hover:border-[#d9fb06]/40 transition-all duration-300"
              >
                {/* Header */}
                <div className="flex items-start justify-between mb-6">
                  <div className="p-3 bg-[#302f2c] rounded-xl border border-[#3f4816]/50 group-hover:border-[#d9fb06]/30 transition-colors">
                    <IconComponent className="text-[#d9fb06]" size={28} />
                  </div>
                  <span className="text-[#3f4816] font-mono text-5xl font-black opacity-50 group-hover:opacity-80 transition-opacity">
                    0{index + 1}
                  </span>
                </div>

                {/* Title */}
                <h3 className="text-xl font-bold text-[#f5f5f4] mb-6 group-hover:text-[#d9fb06] transition-colors">
                  {service.title}
                </h3>

                {/* Items */}
                <ul className="space-y-3">
                  {service.items.map((item, idx) => (
                    <li key={idx} className="flex items-start gap-3">
                      <ArrowRight className="text-[#d9fb06] flex-shrink-0 mt-1" size={14} />
                      <span className="text-[#888680] text-sm leading-relaxed">
                        {item}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};

export default Services;
