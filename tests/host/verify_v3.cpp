// Runs XU2's real parsers over converted data. Every file under the given folders has to load and build.
//
//   verify_v3 [--poses out.json] <folder>...
//
// Build with tests/host/run.bat. Sources come from ../XUtils, same as _tools/check.py finds them.
#include "Test.hpp"

#include "Motion/TrackJson.cpp"
#include "Place/Place.cpp"

#include "Motion/LensTrack.cpp"
#include "Core/Bus.cpp"
#include "Core/Json.cpp"
#include "Core/Mods.cpp"
#include "Math/Ease.cpp"
#include "Motion/Cloud.hpp"
#include "Motion/Curve.cpp"
#include "Motion/Motion.cpp"
#include "Motion/Path.cpp"
#include "Motion/Spec.cpp"
#include "Motion/SpecJson.cpp"
#include "Motion/Spline.cpp"
#include "Motion/Track.cpp"

#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>

using namespace XUtils;
namespace fs = std::filesystem;

static std::string Slurp(const fs::path& aPath)
{
    std::ifstream in(aPath, std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

int main(int argc, char** argv)
{
    std::ofstream poses;
    int first = 1;
    if (argc > 2 && std::string(argv[1]) == "--poses")
    {
        poses.open(argv[2]);
        poses << "[\n";
        first = 3;
    }
    int paths = 0, clouds = 0, skipped = 0, failed = 0;
    bool firstPose = true;
    for (int a = first; a < argc; ++a)
    {
        for (const auto& entry : fs::recursive_directory_iterator(argv[a]))
        {
            if (!entry.is_regular_file() || entry.path().extension() != ".json")
                continue;
            const std::string where = entry.path().generic_string();
            Json::Value json;
            std::string error;
            if (!Json::Parse(Slurp(entry.path()), json, &error))
            {
                std::printf("FAIL %s: %s\n", where.c_str(), error.c_str());
                ++failed;
                continue;
            }
            if (json.Has("motion"))
            {
                Motion::Path path;
                if (!path.FromJson(json, &error))
                {
                    std::printf("FAIL %s: %s\n", where.c_str(), error.c_str());
                    ++failed;
                    continue;
                }
                if (!path.Built())
                {
                    std::printf("FAIL %s: doesn't build: %s\n", where.c_str(), path.Error().c_str());
                    ++failed;
                    continue;
                }
                ++paths;
                if (poses.is_open())
                {
                    if (!firstPose)
                        poses << ",\n";
                    firstPose = false;
                    Json::Value row = Json::Value::MakeObject();
                    row.Set("file", where);
                    row.Set("spec", json);
                    Json::Value samples = Json::Value::MakeArray();
                    constexpr int Count = 21;
                    for (int i = 0; i < Count; ++i)
                    {
                        const double t = path.spec.duration * i / (Count - 1);
                        Motion::PathPose pose;
                        path.PoseAt(t, pose);
                        Json::Value s = Json::Value::MakeArray();
                        for (const double v : {t, pose.position.x, pose.position.y, pose.position.z, pose.yaw, pose.pitch, pose.roll, pose.fov})
                            s.Push(v);
                        samples.Push(s);
                    }
                    row.Set("samples", samples);
                    poses << Json::Write(row, false);
                }
            }
            else if (json.Has("cloud"))
            {
                Motion::Cloud cloud;
                if (!cloud.FromJson(json, &error))
                {
                    std::printf("FAIL %s: %s\n", where.c_str(), error.c_str());
                    ++failed;
                    continue;
                }
                // Read leniently, so check it landed
                if (!cloud.hasCenter || !cloud.hasBox || cloud.Count() == 0 || cloud.points[0].id != 1)
                {
                    std::printf("FAIL %s: center, box or points didn't survive the load\n", where.c_str());
                    ++failed;
                    continue;
                }
                ++clouds;
            }
            else
            {
                // Locations, bbox and paint have no XU2 parser
                ++skipped;
            }
        }
    }
    if (poses.is_open())
        poses << "\n]\n";
    std::printf("%d paths, %d clouds passed, %d other files parsed as JSON only, %d failed\n", paths, clouds, skipped, failed);
    return failed;
}
