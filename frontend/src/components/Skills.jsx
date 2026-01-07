import React from 'react';
import { BookOpen, ArrowUpRight, Terminal, DollarSign, Lock, CloudCog, Server } from 'lucide-react';
import { blogTopics, technicalSkills } from '../data/mock';

const iconMap = {
  'Cloud Cost Optimization': DollarSign,
  'HIPAA-Compliant Cloud Architecture': Lock,
  'Kubernetes Security in Production': Terminal,
  'The Reality of Cloud Migrations': CloudCog,
  'Multi-Cloud Strategy': Server
};

const Skills = () => {
  return (
    <section id="skills" className="py-24 bg-[#1a1c1b] relative">
      <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#3f4816] to-transparent" />
      
      <div className="max-w-7xl mx-auto px-6 lg:px-10">
        <div className="grid lg:grid-cols-2 gap-16">
          {/* Technical Skills */}
          <div>
            <div className="mb-10">
              <span className="text-[#d9fb06] text-sm font-semibold uppercase tracking-widest">Technical Expertise</span>
              <h2 className="text-4xl font-black text-[#f5f5f4] mt-4">
                Tech Stack
              </h2>
            </div>

            <div className="space-y-6">
              {Object.entries(technicalSkills).map(([category, skills]) => (
                <div key={category}>
                  <h4 className="text-[#d9fb06] text-sm font-semibold mb-3">{category}</h4>
                  <div className="flex flex-wrap gap-2">
                    {Array.isArray(skills) ? (
                      skills.map((skill) => (
                        <span
                          key={skill}
                          className="px-3 py-1.5 bg-[#302f2c] text-[#f5f5f4] text-xs font-mono rounded-lg border border-[#3f4816]/50 hover:border-[#d9fb06]/50 hover:text-[#d9fb06] transition-all cursor-default"
                        >
                          {skill}
                        </span>
                      ))
                    ) : (
                      Object.entries(skills).map(([platform, platformSkills]) => (
                        <div key={platform} className="w-full mb-3">
                          <span className="text-[#888680] text-xs font-medium uppercase tracking-wider mb-2 block">{platform}</span>
                          <div className="flex flex-wrap gap-2">
                            {platformSkills.map((skill) => (
                              <span
                                key={skill}
                                className="px-3 py-1.5 bg-[#302f2c] text-[#f5f5f4] text-xs font-mono rounded-lg border border-[#3f4816]/50 hover:border-[#d9fb06]/50 hover:text-[#d9fb06] transition-all cursor-default"
                              >
                                {skill}
                              </span>
                            ))}
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Writing & Knowledge Sharing */}
          <div>
            <div className="mb-10">
              <div className="flex items-center gap-2">
                <BookOpen className="text-[#d9fb06]" size={20} />
                <span className="text-[#d9fb06] text-sm font-semibold uppercase tracking-widest">Knowledge Sharing</span>
              </div>
              <h2 className="text-4xl font-black text-[#f5f5f4] mt-4">
                Writing Topics
              </h2>
              <p className="text-[#888680] mt-4 leading-relaxed">
                I believe in learning in public and sharing knowledge with the community.
              </p>
            </div>

            <div className="space-y-4">
              {blogTopics.map((topic) => {
                const IconComponent = iconMap[topic.title] || Terminal;
                return (
                  <div
                    key={topic.id}
                    className="p-5 bg-[#302f2c] border border-[#3f4816]/50 rounded-xl hover:border-[#d9fb06]/30 transition-all group cursor-pointer"
                  >
                    <div className="flex items-start gap-4">
                      <div className="p-2 bg-[#1a1c1b] rounded-lg">
                        <IconComponent className="text-[#d9fb06]" size={20} />
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center justify-between">
                          <h4 className="text-[#f5f5f4] font-semibold group-hover:text-[#d9fb06] transition-colors">
                            {topic.title}
                          </h4>
                          <ArrowUpRight className="text-[#888680] group-hover:text-[#d9fb06] transition-colors" size={18} />
                        </div>
                        <p className="text-[#888680] text-sm mt-2 leading-relaxed">
                          {topic.description}
                        </p>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Skills;
