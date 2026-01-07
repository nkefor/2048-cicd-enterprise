import React, { useState } from 'react';
import { ChevronRight, ExternalLink, ChevronDown, ChevronUp } from 'lucide-react';
import { projects } from '../data/mock';

const Projects = () => {
  const [expandedProject, setExpandedProject] = useState(0);

  return (
    <section id="projects" className="py-24 bg-[#1a1c1b] relative">
      <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#3f4816] to-transparent" />
      
      <div className="max-w-7xl mx-auto px-6 lg:px-10">
        {/* Section Header */}
        <div className="mb-16">
          <span className="text-[#d9fb06] text-sm font-semibold uppercase tracking-widest">Notable Projects</span>
          <h2 className="text-4xl md:text-5xl font-black text-[#f5f5f4] mt-4 leading-tight">
            Real Impact,<br />
            <span className="text-[#888680]">Measurable Results</span>
          </h2>
        </div>

        {/* Projects List */}
        <div className="space-y-4">
          {projects.map((project, index) => (
            <div
              key={project.id}
              className={`border rounded-2xl transition-all duration-300 overflow-hidden ${
                expandedProject === index
                  ? 'bg-[#302f2c] border-[#d9fb06]/40'
                  : 'bg-[#302f2c]/30 border-[#3f4816]/50 hover:border-[#3f4816]'
              }`}
            >
              {/* Project Header */}
              <button
                onClick={() => setExpandedProject(expandedProject === index ? -1 : index)}
                className="w-full p-6 md:p-8 flex items-center justify-between text-left"
              >
                <div className="flex items-center gap-4 md:gap-6">
                  <span className="text-[#d9fb06] font-mono text-sm">0{index + 1}</span>
                  <h3 className="text-lg md:text-xl font-bold text-[#f5f5f4]">
                    {project.title}
                  </h3>
                </div>
                <div className="flex items-center gap-4">
                  {project.results.slice(0, 2).map((result, idx) => (
                    <div key={idx} className="hidden md:block text-right">
                      <div className="text-[#d9fb06] font-bold">{result.metric}</div>
                      <div className="text-[#888680] text-xs">{result.label}</div>
                    </div>
                  ))}
                  {expandedProject === index ? (
                    <ChevronUp className="text-[#d9fb06]" size={24} />
                  ) : (
                    <ChevronDown className="text-[#888680]" size={24} />
                  )}
                </div>
              </button>

              {/* Expanded Content */}
              {expandedProject === index && (
                <div className="px-6 md:px-8 pb-8 space-y-8">
                  {/* Challenge */}
                  <div>
                    <h4 className="text-[#d9fb06] text-sm font-semibold uppercase tracking-wider mb-3">Challenge</h4>
                    <p className="text-[#f5f5f4] leading-relaxed">{project.challenge}</p>
                  </div>

                  {/* Approach */}
                  <div>
                    <h4 className="text-[#d9fb06] text-sm font-semibold uppercase tracking-wider mb-3">Approach</h4>
                    <ul className="space-y-2">
                      {project.approach.map((item, idx) => (
                        <li key={idx} className="flex items-start gap-3">
                          <ChevronRight className="text-[#d9fb06] flex-shrink-0 mt-1" size={14} />
                          <span className="text-[#888680] text-sm leading-relaxed">{item}</span>
                        </li>
                      ))}
                    </ul>
                  </div>

                  {/* Results Grid */}
                  <div>
                    <h4 className="text-[#d9fb06] text-sm font-semibold uppercase tracking-wider mb-4">Results</h4>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      {project.results.map((result, idx) => (
                        <div
                          key={idx}
                          className="p-4 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl text-center"
                        >
                          <div className="text-2xl md:text-3xl font-black text-[#d9fb06] mb-1">
                            {result.metric}
                          </div>
                          <div className="text-[#888680] text-xs uppercase tracking-wider">
                            {result.label}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Technologies */}
                  <div>
                    <h4 className="text-[#d9fb06] text-sm font-semibold uppercase tracking-wider mb-3">Technologies</h4>
                    <div className="flex flex-wrap gap-2">
                      {project.technologies.map((tech) => (
                        <span
                          key={tech}
                          className="px-3 py-1.5 bg-[#1a1c1b] text-[#f5f5f4] text-xs font-mono rounded-lg border border-[#3f4816]/50"
                        >
                          {tech}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Projects;
