#!/usr/bin/env python3
#
# Converts the hand-written OpenCL kernel structures to precision aware types
# (REAL/cl_double) and generates the host-side double layouts (*D structures)
# together with promotion helpers used by the dynamic data builders.
#
# usage: tools/generateOpenCLPrecisionHeaders.py [nondry]
#
import os
import re
import sys

PROJECT_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# Files whose structures describe geometry/data shared with the host.
TARGET_FILES = [
	"opencl/material_cl.h",
	"opencl/light_cl.h",
	"opencl/primitives_cl.h",
	"opencl/object_data_cl.h",
	"opencl/node_data_cl.h",
	"opencl/hybrid_sequence_cl.h",
	"opencl/input_data_structures.h",
	"opencl/mesh_export_data_cl.h",
]

# Structures whose numeric members must stay single precision (image/color
# pipelines). These files are not precision-converted at all.
SKIP_STRUCTS = {
	"sClPixel",
	"sParamsDOF",
	"sSortedZBufferCl",
	"sParamsSSAO",
	"sParamsChromaticAberrationCl",
	"sParamsHDRBlurCl",
	"sNebulaSequenceCl",
	"sShaderInputDataCl",
	"sClGradientsCollection",
	"sRenderData",
}

MARK_BEGIN = "// BEGIN OPENCL_D_STRUCTS"
MARK_END = "// END OPENCL_D_STRUCTS"


def read_file(path):
	with open(path, "r", encoding="utf-8") as f:
		return f.read()


def write_file(path, content):
	with open(path, "w", encoding="utf-8", newline="\n") as f:
		f.write(content)


def strip_d_block(content):
	# Remove the complete generated block, including its preprocessor guard and
	# any blank lines that previous generator runs added before the block. The
	# rewrite must be idempotent: repeated runs must not accumulate blank lines.
	pattern = re.compile(
		r"\n\s*#ifndef OPENCL_KERNEL_CODE\s*\n" + re.escape(MARK_BEGIN) +
		r"[\s\S]*?" + re.escape(MARK_END) + r".*?#endif /\* OPENCL_KERNEL_CODE \*/\s*\n",
		re.S)
	content = re.sub(pattern, "\n", content)
	# Remove an empty leftover block from earlier revisions.
	content = re.sub(r"\n\s*#ifndef OPENCL_KERNEL_CODE\s*\n#endif /\* OPENCL_KERNEL_CODE \*/\s*\n", "\n", content)
	return content.rstrip("\n") + "\n"


def parse_structs(content):
	"""Return (kind, name, body) for typedef struct/union definitions."""
	result = []
	pattern = re.compile(r"typedef (struct|union)(?: ALIGN16| ALIGN_REAL)?\s*\n\{")
	for m in pattern.finditer(content):
		kind = m.group(1)
		brace_start = content.index("{", m.start())
		depth = 0
		j = brace_start
		while j < len(content):
			if content[j] == "{":
				depth += 1
			elif content[j] == "}":
				depth -= 1
				if depth == 0:
					break
			j += 1
		tail = content[j + 1:]
		name_match = re.match(r"\s*([A-Za-z0-9_]+)\s*;", tail)
		if not name_match:
			continue
		result.append((kind, name_match.group(1), content[brace_start + 1:j]))
	return result


def parse_fields(body):
	fields = []
	for raw_line in body.split("\n"):
		line = raw_line.strip()
		if not line or line.startswith("//"):
			continue
		line = line.split("//")[0].strip()
		if not line.endswith(";") or "*" in line or line.startswith(("typedef ", "struct ", "enum ", "union ")):
			continue
		decl = line[:-1].strip()
		m = re.match(r"^([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(\[[^\]]*\]\s*)*$", decl)
		if not m:
			continue
		type_name = m.group(1)
		rest = decl[len(type_name):].strip()
		name_match = re.match(r"([A-Za-z0-9_]+)", rest)
		if not name_match:
			continue
		arrays = re.findall(r"\[([^\]]*)\]", rest)
		fields.append((type_name, name_match.group(1), arrays))
	return fields


def transform_kernel_text(text):
	text = text.replace("typedef struct ALIGN16", "typedef struct ALIGN_REAL")
	text = text.replace("typedef union ALIGN16", "typedef union ALIGN_REAL")
	text = re.sub(r"\bcl_float4\b", "REAL4", text)
	text = re.sub(r"\bcl_float3\b", "REAL3", text)
	text = re.sub(r"\bcl_float2\b", "REAL2", text)
	text = re.sub(r"\bcl_float\b", "REAL", text)
	return text


def transform_kernel_structs(content):
	"""Convert the kernel layout, but keep structs listed in SKIP_STRUCTS
	(image/display pipelines) in single precision."""
	pattern = re.compile(r"typedef (struct|union)(?: ALIGN16| ALIGN_REAL)?\s*\n\{")
	out = []
	last = 0
	for m in pattern.finditer(content):
		brace_start = content.index("{", m.start())
		depth = 0
		j = brace_start
		while j < len(content):
			if content[j] == "{":
				depth += 1
			elif content[j] == "}":
				depth -= 1
				if depth == 0:
					break
			j += 1
		tail = content[j + 1:]
		name_match = re.match(r"\s*([A-Za-z0-9_]+)\s*;", tail)
		if not name_match:
			continue
		end = j + 1 + len(tail) - len(tail.lstrip())
		end = content.find(";", j) + 1
		name = name_match.group(1)
		out.append(transform_kernel_text(content[last:m.start()]))
		block = content[m.start():end]
		if name in SKIP_STRUCTS:
			out.append(block)
		else:
			out.append(transform_kernel_text(block))
		last = end
	out.append(transform_kernel_text(content[last:]))
	return "".join(out)


def transform_d_struct(kind, name, body):
	result = []
	result.append("typedef %s ALIGN_DOUBLE" % kind)
	result.append("{")
	lines = body.strip("\n").split("\n")
	for line in lines:
		line = re.sub(r"\bcl_float4\b", "cl_double4", line)
		line = re.sub(r"\bcl_float3\b", "cl_double3", line)
		line = re.sub(r"\bcl_float2\b", "cl_double2", line)
		line = re.sub(r"\bcl_float\b", "cl_double", line)
		line = re.sub(r"\bREAL4\b", "cl_double4", line)
		line = re.sub(r"\bREAL3\b", "cl_double3", line)
		line = re.sub(r"\bREAL2\b", "cl_double2", line)
		line = re.sub(r"\bREAL\b", "cl_double", line)
		line = re.sub(r"\bmatrix33\b", "matrix33D", line)
		line = re.sub(r"\bmatrix44\b", "matrix44D", line)
		line = re.sub(r"\b([su])([A-Za-z0-9_]+)Cl\b", r"\1\2ClD", line)
		result.append(line)
	result.append("} %sD;" % name)
	return "\n".join(result)


def helper_name(name, suffix):
	return "clPromote" + name[0].upper() + name[1:] + suffix


def copy_expression(type_name, dest):
	type_name_d = re.sub(r"\b([su])([A-Za-z0-9_]+)Cl\b", r"\1\2ClD", type_name)
	if type_name_d != type_name:
		return "clPromote%sD(source.%s);" % (type_name[0].upper() + type_name[1:], dest)
	if type_name == "REAL3":
		return "toClDouble3(source." + dest + ");"
	if type_name == "REAL4":
		return "toClDouble4(source." + dest + ");"
	if type_name == "REAL2":
		return "toClDouble2(source." + dest + ");"
	if type_name == "matrix33":
		return "toClMatrix33D(source." + dest + ");"
	if type_name == "matrix44":
		return "toClMatrix44D(source." + dest + ");"
	if type_name in ("cl_float3", "cl_float4", "cl_float2"):
		return "toClFloat%s(source.%s);" % (type_name[7:], dest)
	if type_name in ("cl_double3", "cl_double4", "cl_double2"):
		return "toClDouble%s(source.%s);" % (type_name[8:], dest)
	if re.match(r"^enum[A-Za-z0-9_]+Cl$", type_name):
		return "static_cast<%s>(source.%s);" % (type_name, dest)
	return None


def build_promote_helper(name, fields):
	out = []
	out.append("inline %sD %s(const %s &source)" % (name, helper_name(name, "D"), name))
	out.append("{")
	out.append("\t%sD target;" % name)
	for type_name, field_name, arrays in fields:
		prefix = ""
		dest = field_name
		if arrays:
			for index, size in enumerate(arrays):
				v = chr(ord("i") + index)
				prefix += "for(int %s = 0; %s < %s; %s++){" % (v, v, size, v)
				dest += "[" + v + "]"
		expr = copy_expression(type_name, dest)
		if expr is None:
			expr = "source.%s;" % dest
		out.append("\t" + prefix + "target." + dest + " = " + expr + "}" * len(arrays))
	out.append("\treturn target;")
	out.append("}")
	return "\n".join(out)


def struct_base_name(name):
	"""sMaterialCl -> Material, used to locate the clCopyS...Cl helper."""
	name = re.sub(r"^[su]", "", name)
	return re.sub(r"Cl$", "", name)


def find_copy_function(content, name):
	"""Return the body of an existing clCopyS<Name>Cl(..) helper, if any."""
	base = struct_base_name(name)
	pattern = re.compile(r"^(?:\s*)([A-Za-z0-9_]+)\s+clCopyS" + re.escape(base) +
		r"Cl\([^;]*\)\s*\n\{", re.M)
	m = pattern.search(content)
	if not m:
		return None
	brace_start = content.index("{", m.start())
	depth = 0
	j = brace_start
	while j < len(content):
		if content[j] == "{":
			depth += 1
		elif content[j] == "}":
			depth -= 1
			if depth == 0:
				break
		j += 1
	return content[m.start():j + 1]


def build_copy_d_helper(name, body):
	base = struct_base_name(name)
	body = body.replace("clCopyS" + base + "Cl(", "clCopyS" + base + "ClD(")
	body = re.sub(r"\bs" + re.escape(base) + r"Cl\b", "s" + base + "ClD", body)
	body = re.sub(r"\bclCopyS([A-Za-z0-9_]+)Cl\(", r"clCopyS\1ClD(", body)
	body = re.sub(r"\btoClFloat3\b", "toClDouble3", body)
	body = re.sub(r"\btoClFloat2\b", "toClDouble2", body)
	body = re.sub(r"\btoClFloat4\b", "toClDouble4", body)
	body = re.sub(r"\btoClFloatMatrix33\b", "toClMatrix33D", body)
	body = re.sub(r"\btoClFloatMatrix44\b", "toClMatrix44D", body)
	body = re.sub(r"\btoClMatrix33\b", "toClMatrix33D", body)
	body = re.sub(r"\btoClMatrix44\b", "toClMatrix44D", body)
	body = re.sub(r"\bcl_float\b", "cl_double", body)
	return body


def generate_d_section(content):
	structs = [(kind, name, body) for kind, name, body in parse_structs(content)
		if name not in SKIP_STRUCTS]
	if not structs:
		return ""
	parts = []
	for kind, name, body in structs:
		parts.append(transform_d_struct(kind, name, body))
		copy_body = find_copy_function(content, name)
		if copy_body:
			parts.append(build_copy_d_helper(name, copy_body))
		parts.append(build_promote_helper(name, parse_fields(body)))
	return "\n\n".join(parts)


def process_file(path, dry):
	content = read_file(path)
	content = strip_d_block(content)
	content = transform_kernel_structs(content)
	section = generate_d_section(content)
	if section:
		marker = "\n#ifndef OPENCL_KERNEL_CODE\n" + MARK_BEGIN + "\n" + section + "\n" + MARK_END + "\n#endif /* OPENCL_KERNEL_CODE */\n"
		# Insert inside the file's header guard so repeated inclusion does not
		# redefine the host double structures.
		guards = list(re.finditer(r"^#endif[^\n]*$", content, re.M))
		if guards:
			guard = guards[-1]
			content = content[:guard.start()] + marker + "\n" + content[guard.start():]
		else:
			content = content.rstrip("\n") + "\n" + marker
	old = read_file(path)
	if content != old:
		if not dry:
			write_file(path, content)
		print("  %s: file changed%s" % (os.path.basename(path), "" if not dry else " (dry)"))
	else:
		print("  %s: unchanged" % os.path.basename(path))


def main():
	dry = not (len(sys.argv) > 1 and sys.argv[1] == "nondry")
	print("RUNNING OPENCL PRECISION HEADER GENERATION" + (" (dry run)" if dry else ""))
	for rel in TARGET_FILES:
		process_file(os.path.join(PROJECT_PATH, rel), dry)


if __name__ == "__main__":
	main()
