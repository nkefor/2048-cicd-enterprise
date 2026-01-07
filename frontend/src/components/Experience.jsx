import React from 'react';
import { Briefcase, ChevronRight, Calendar } from 'lucide-react';
import { experience, certifications, education } from '../data/mock';

const Experience = () => {
  return (
    <section id="experience" className="py-24 bg-[#302f2c]/30 relative">
      <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#3f4816] to-transparent" />
      
      <div className="max-w-7xl mx-auto px-6 lg:px-10">
        {/* Section Header */}
        <div className="mb-16">
          <span className="text-[#d9fb06] text-sm font-semibold uppercase tracking-widest">Experience</span>
          <h2 className="text-4xl md:text-5xl font-black text-[#f5f5f4] mt-4 leading-tight">
            Career Journey<br />
            <span className="text-[#888680]">& Credentials</span>
          </h2>
        </div>

        <div className="grid lg:grid-cols-3 gap-12">
          {/* Work Experience */}
          <div className="lg:col-span-2">
            <div className="flex items-center gap-3 mb-8">
              <Briefcase className="text-[#d9fb06]" size={20} />
              <h3 className="text-xl font-bold text-[#f5f5f4]">Work Experience</h3>
            </div>

            <div className="space-y-6">
              {experience.map((job, index) => (
                <div
                  key={job.id}
                  className="relative pl-8 pb-8 border-l-2 border-[#3f4816]/50 last:pb-0 group"
                >
                  {/* Timeline Dot */}
                  <div className="absolute -left-[9px] top-0 w-4 h-4 bg-[#1a1c1b] border-2 border-[#d9fb06] rounded-full group-hover:bg-[#d9fb06] transition-colors" />
                  
                  {/* Content */}
                  <div className="p-6 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl hover:border-[#d9fb06]/30 transition-all">
                    <div className="flex flex-wrap items-center gap-3 mb-2">
                      <span className="text-[#d9fb06] font-bold text-lg">{job.company}</span>
                      <span className="text-[#888680]">•</span>
                      <span className="text-[#f5f5f4] font-medium">{job.role}</span>
                    </div>
                    
                    <div className="flex items-center gap-2 text-[#888680] text-sm mb-4">
                      <Calendar size={14} />
                      <span>{job.period}</span>
                    </div>

                    <ul className="space-y-2">
                      {job.highlights.map((highlight, idx) => (
                        <li key={idx} className="flex items-start gap-2">
                          <ChevronRight className="text-[#d9fb06] flex-shrink-0 mt-0.5" size={14} />
                          <span className="text-[#888680] text-sm leading-relaxed">{highlight}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Certifications & Education */}
          <div className="space-y-12">
            {/* Certifications */}
            <div>
              <h3 className="text-xl font-bold text-[#f5f5f4] mb-6">Certifications</h3>
              <div className="space-y-3">
                {certifications.map((cert) => (
                  <div
                    key={cert.id}
                    className="p-4 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl hover:border-[#d9fb06]/30 transition-all group"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <h4 className="text-[#f5f5f4] font-medium text-sm leading-snug group-hover:text-[#d9fb06] transition-colors">
                          {cert.name}
                        </h4>
                        <p className="text-[#888680] text-xs mt-1">{cert.issuer}</p>
                      </div>
                      <span
                        className={`px-2 py-1 text-xs font-medium rounded-full flex-shrink-0 ${
                          cert.status === 'active'
                            ? 'bg-[#3f4816]/50 text-[#d9fb06]'
                            : 'bg-[#302f2c] text-[#888680]'
                        }`}
                      >
                        {cert.status === 'active' ? 'Active' : 'In Progress'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Education */}
            <div>
              <h3 className="text-xl font-bold text-[#f5f5f4] mb-6">Education</h3>
              <div className="space-y-3">
                {education.map((edu) => (
                  <div
                    key={edu.id}
                    className="p-4 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl"
                  >
                    <h4 className="text-[#f5f5f4] font-medium text-sm leading-snug">
                      {edu.degree}
                    </h4>
                    <p className="text-[#888680] text-xs mt-1">{edu.school}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Experience;
